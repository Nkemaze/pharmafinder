import 'dart:convert';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../models/drug.dart';

class DrugManagementPage extends StatefulWidget {
  const DrugManagementPage({super.key});
  @override
  State<DrugManagementPage> createState() => _DrugManagementPageState();
}

class _DrugManagementPageState extends State<DrugManagementPage> {
  String get _pharmacyId => FirebaseAuth.instance.currentUser!.uid;
  CollectionReference get _drugsRef => FirebaseFirestore.instance
      .collection('pharmacies')
      .doc(_pharmacyId)
      .collection('drugs');

  String _selectedCategory = 'All Categories';
  String _selectedStatus = 'All Status';
  int _currentPage = 1;
  static const int _pageSize = 10;

  void _showAddDrugDialog(List<String> existingCategories) {
    showDialog(
      context: context,
      builder: (context) => _DrugDialog(
        categories: existingCategories,
        onSave: (map) async {
          final nav = Navigator.of(this.context);
          final messenger = ScaffoldMessenger.of(this.context);
          try {
            await _drugsRef.add(map);
            if (mounted) nav.pop();
          } catch (e) {
            if (mounted) {
              messenger.showSnackBar(
                SnackBar(content: Text('Error saving drug: $e')),
              );
            }
          }
        },
      ),
    );
  }

  void _showEditDrugDialog(Drug drug, List<String> existingCategories) {
    showDialog(
      context: context,
      builder: (context) => _DrugDialog(
        drug: drug,
        categories: existingCategories,
        onSave: (map) async {
          final nav = Navigator.of(this.context);
          final messenger = ScaffoldMessenger.of(this.context);
          try {
            await drug.reference!.update(map);
            if (mounted) nav.pop();
          } catch (e) {
            if (mounted) {
              messenger.showSnackBar(
                SnackBar(content: Text('Error updating drug: $e')),
              );
            }
          }
        },
      ),
    );
  }

  void _showRestockDialog(Drug drug) {
    showDialog(
      context: context,
      builder: (context) => _RestockDialog(
        drug: drug,
        onRestock: (unitQty, unitPrice, packetQty, packetPrice) async {
          final messenger = ScaffoldMessenger.of(this.context);
          final updates = <String, dynamic>{};
          int totalAdded = 0;
          if (unitQty > 0) {
            totalAdded += unitQty;
          }
          if (packetQty > 0 && drug.packetSize != null) {
            totalAdded += packetQty * drug.packetSize!;
          }
          if (totalAdded > 0) {
            updates['quantity'] = FieldValue.increment(totalAdded);
          }
          if (unitPrice != null) {
            updates['pricePerUnit'] = unitPrice;
          }
          if (packetPrice != null) {
            updates['pricePerPacket'] = packetPrice;
          }
          try {
            if (updates.isNotEmpty) {
              await drug.reference!.update(updates);
            }
            if (mounted) {
              messenger.showSnackBar(
                SnackBar(
                  content: Text('${drug.name} restocked successfully'),
                  backgroundColor: AppColors.secondary,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              messenger.showSnackBar(
                SnackBar(content: Text('Error restocking: $e')),
              );
            }
          }
        },
      ),
    );
  }

  void _showSellDialog(Drug drug) {
    showDialog(
      context: context,
      builder: (context) => _SellDialog(
        drug: drug,
        transactionsRef: FirebaseFirestore.instance
            .collection('pharmacies')
            .doc(_pharmacyId)
            .collection('transactions'),
      ),
    );
  }

  Future<void> _deleteDrug(Drug drug) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete drug'),
        content: Text('Are you sure you want to delete "${drug.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await drug.reference!.delete();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting drug: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _drugsRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}',
                style: const TextStyle(color: AppColors.error)),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        final allDrugs = docs
            .map((d) => Drug.fromMap(d.id, d.data() as Map<String, dynamic>,
                reference: d.reference))
            .toList();

        final totalDrugs = allDrugs.length;
        final lowStock =
            allDrugs.where((d) => d.quantity > 0 && d.quantity <= 10).length;
        final outOfStock = allDrugs.where((d) => d.quantity == 0).length;
        final totalValue =
            allDrugs.fold<double>(0, (acc, d) => acc + d.pricePerUnit * d.quantity);

        final categories = <String>{'All Categories'};
        for (final d in allDrugs) {
          if (d.category.isNotEmpty) categories.add(d.category);
        }
        final categoryList = categories.toList()..sort();

        List<Drug> filtered = allDrugs;
        if (_selectedCategory != 'All Categories') {
          filtered =
              filtered.where((d) => d.category == _selectedCategory).toList();
        }
        if (_selectedStatus == 'In Stock') {
          filtered = filtered.where((d) => d.inStock).toList();
        } else if (_selectedStatus == 'Low Stock') {
          filtered =
              filtered.where((d) => d.inStock && d.quantity <= 10).toList();
        } else if (_selectedStatus == 'Out of Stock') {
          filtered = filtered.where((d) => !d.inStock).toList();
        }

        final totalPages = (filtered.length / _pageSize).ceil().clamp(1, 999);
        if (_currentPage > totalPages) _currentPage = totalPages;
        final startIndex = (_currentPage - 1) * _pageSize;
        final pageDrugs = filtered.skip(startIndex).take(_pageSize).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Drug Inventory',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Manage and monitor your clinical stock levels in real-time.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.file_download_outlined, size: 18),
                        label: const Text('Export CSV'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => _showAddDrugDialog(categoryList),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Drug'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _StatsTile(
                      label: 'Total SKUs',
                      value: '$totalDrugs',
                      badge: '$totalDrugs drugs',
                      badgeColor: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _StatsTile(
                      label: 'Low Stock Alerts',
                      value: '$lowStock',
                      badge: lowStock > 0 ? 'Attention needed' : 'All clear',
                      badgeColor: lowStock > 0
                          ? AppColors.onSurfaceVariant
                          : AppColors.secondary,
                      valueColor: lowStock > 0 ? AppColors.error : null,
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _StatsTile(
                      label: 'Out of Stock',
                      value: '$outOfStock',
                      badge: outOfStock > 0 ? 'Urgent reorder' : 'None',
                      badgeColor: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _StatsTile(
                      label: 'Inventory Value',
                      value: _formatValue(totalValue),
                      badge: 'FCFA',
                      badgeColor: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                  border: Border(
                    bottom: BorderSide(color: AppColors.outlineVariant),
                    left: BorderSide(color: AppColors.outlineVariant),
                    right: BorderSide(color: AppColors.outlineVariant),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _FilterChip(
                          label: 'Filter by:',
                          value: _selectedCategory,
                          options: categoryList,
                          onChanged: (v) => setState(() {
                            _selectedCategory = v;
                            _currentPage = 1;
                          }),
                        ),
                        const SizedBox(width: 12),
                        _FilterChip(
                          label: 'Status:',
                          value: _selectedStatus,
                          options: const [
                            'All Status',
                            'In Stock',
                            'Low Stock',
                            'Out of Stock'
                          ],
                          onChanged: (v) => setState(() {
                            _selectedStatus = v;
                            _currentPage = 1;
                          }),
                        ),
                      ],
                    ),
                    Text(
                      filtered.isEmpty
                          ? 'No drugs to display'
                          : 'Showing ${startIndex + 1}-${(startIndex + _pageSize).clamp(1, filtered.length)} of ${filtered.length} drugs',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius:
                      BorderRadius.vertical(bottom: Radius.circular(12)),
                  border: Border(
                    left: BorderSide(color: AppColors.outlineVariant),
                    right: BorderSide(color: AppColors.outlineVariant),
                    bottom: BorderSide(color: AppColors.outlineVariant),
                  ),
                ),
                child: Column(
                  children: [
                    if (pageDrugs.isEmpty)
                      const SizedBox(
                        height: 240,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.medication_outlined,
                                size: 40,
                                color: AppColors.onSurfaceVariant,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'No drugs match the selected filters.',
                                style: TextStyle(color: AppColors.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Table(
                        columnWidths: const {
                          0: FlexColumnWidth(3),
                          1: FlexColumnWidth(1.5),
                          2: FlexColumnWidth(1.5),
                          3: FlexColumnWidth(1),
                          4: FlexColumnWidth(2),
                        },
                        children: [
                          _buildTableHeader(),
                          for (final drug in pageDrugs)
                            _buildDrugRow(drug, categoryList),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton(
                    onPressed:
                        _currentPage > 1 ? () => setState(() => _currentPage--) : null,
                    child: const Text('Previous'),
                  ),
                  Row(
                    children: [
                      for (int i = 1; i <= totalPages.clamp(1, 5); i++)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: _PageButton(
                            page: '$i',
                            isActive: i == _currentPage,
                            onTap: () => setState(() => _currentPage = i),
                          ),
                        ),
                    ],
                  ),
                  OutlinedButton(
                    onPressed: _currentPage < totalPages
                        ? () => setState(() => _currentPage++)
                        : null,
                    child: const Text('Next'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  static String _formatValue(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  TableRow _buildTableHeader() {
    return TableRow(
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
      ),
      children: ['Drug Name', 'Price', 'Stock', 'Qty', 'Actions']
          .map((h) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  h.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ))
          .toList(),
    );
  }

  TableRow _buildDrugRow(Drug drug, List<String> categories) {
    final stockColor = drug.inStock
        ? (drug.quantity <= 10 ? Colors.amber.shade700 : AppColors.secondary)
        : AppColors.error;
    final stockBg = drug.inStock
        ? (drug.quantity <= 10
            ? Colors.amber.shade50
            : AppColors.secondary.withValues(alpha: 0.1))
        : AppColors.errorContainer;
    final stockText = drug.inStock
        ? (drug.quantity <= 10 ? 'Low Stock' : 'In Stock')
        : 'Out of Stock';

    final priceLabel = drug.pricePerPacket != null
        ? '${drug.pricePerUnit.toStringAsFixed(0)}/${drug.unitLabel} | ${drug.pricePerPacket!.toStringAsFixed(0)}/pkt'
        : '${drug.pricePerUnit.toStringAsFixed(0)}/${drug.unitLabel}';

    return TableRow(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.outlineVariant, width: 0.3),
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: drug.imageUrl != null && drug.imageUrl!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          drug.imageUrl!,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                           errorBuilder: (_, e, s) => const Icon(
                               Icons.medication_rounded,
                               color: AppColors.primary,
                               size: 20),
                        ),
                      )
                    : const Icon(Icons.medication_rounded,
                        color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      drug.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface,
                      ),
                    ),
                    Text(
                      drug.category.isEmpty ? 'Uncategorized' : drug.category,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            priceLabel,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              fontFamily: 'monospace',
              color: AppColors.onSurface,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: stockBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: stockColor.withValues(alpha: 0.2)),
            ),
            child: Text(
              stockText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: stockColor,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            '${drug.quantity}',
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                fontFamily: 'monospace',
                color: AppColors.onSurface),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ActionIcon(
                icon: Icons.add_circle_outline,
                color: AppColors.primary,
                tooltip: 'Restock',
                onTap: () => _showRestockDialog(drug),
              ),
              const SizedBox(width: 4),
              _ActionIcon(
                icon: Icons.shopping_cart_outlined,
                color: AppColors.tertiary,
                tooltip: 'Sell',
                onTap: () => _showSellDialog(drug),
              ),
              const SizedBox(width: 4),
              _ActionIcon(
                icon: Icons.edit_outlined,
                color: AppColors.onSurfaceVariant,
                tooltip: 'Edit',
                onTap: () => _showEditDrugDialog(drug, categories),
              ),
              const SizedBox(width: 4),
              _ActionIcon(
                icon: Icons.delete_outline,
                color: AppColors.error,
                tooltip: 'Delete',
                onTap: () => _deleteDrug(drug),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// ACTION ICON
// =============================================================================

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

// =============================================================================
// STATS TILE
// =============================================================================

class _StatsTile extends StatelessWidget {
  final String label;
  final String value;
  final String badge;
  final Color badgeColor;
  final Color? valueColor;
  const _StatsTile({
    required this.label,
    required this.value,
    required this.badge,
    required this.badgeColor,
    this.valueColor,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurfaceVariant,
                  letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: valueColor ?? AppColors.onSurface,
                      letterSpacing: -0.5)),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(badge,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: badgeColor)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final List<String> options;
  final Function(String) onChanged;
  const _FilterChip({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          Text('$label ',
              style: const TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant)),
          DropdownButton<String>(
            value: value,
            underline: const SizedBox(),
            isDense: true,
            style: const TextStyle(
                fontSize: 13, color: AppColors.onSurface, fontWeight: FontWeight.w500),
            items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
            onChanged: (v) => onChanged(v!),
          ),
        ],
      ),
    );
  }
}

class _PageButton extends StatelessWidget {
  final String page;
  final bool isActive;
  final VoidCallback? onTap;
  const _PageButton({required this.page, this.isActive = false, this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(8),
          border: isActive ? null : Border.all(color: AppColors.outlineVariant),
        ),
        child: Center(
          child: Text(page,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : AppColors.onSurfaceVariant)),
        ),
      ),
    );
  }
}

// =============================================================================
// DRUG DIALOG (Add/Edit)
// =============================================================================

class _DrugDialog extends StatefulWidget {
  final Drug? drug;
  final List<String> categories;
  final Future<void> Function(Map<String, dynamic> map) onSave;
  const _DrugDialog({this.drug, required this.categories, required this.onSave});
  @override
  State<_DrugDialog> createState() => _DrugDialogState();
}

class _DrugDialogState extends State<_DrugDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _pricePerUnitController;
  late final TextEditingController _pricePerPacketController;
  late final TextEditingController _packetSizeController;
  late final TextEditingController _quantityController;
  late String _category;
  late String _unitLabel;
  DateTime? _expiryDate;
  bool _saving = false;
  String? _nameError;
  String? _pricePerUnitError;
  String? _quantityError;
  bool _hasPacketPricing = false;

  Uint8List? _pickedImageBytes;
  String? _pickedImageName;
  String? _existingImageUrl;
  bool _imageRemoved = false;
  bool _uploadingImage = false;

  bool get _isEditing => widget.drug != null;

  @override
  void initState() {
    super.initState();
    final d = widget.drug;
    _nameController = TextEditingController(text: d?.name ?? '');
    _pricePerUnitController = TextEditingController(
        text: d != null ? d.pricePerUnit.toStringAsFixed(0) : '');
    _pricePerPacketController = TextEditingController(
        text: d?.pricePerPacket != null ? d!.pricePerPacket!.toStringAsFixed(0) : '');
    _packetSizeController = TextEditingController(
        text: d?.packetSize != null ? d!.packetSize.toString() : '');
    _quantityController = TextEditingController(
        text: d != null ? d.quantity.toString() : '');
    _category = d?.category ?? '';
    _unitLabel = d?.unitLabel ?? 'unit';
    _expiryDate = d?.expiryDate;
    _hasPacketPricing = d?.pricePerPacket != null;
    _existingImageUrl = d?.imageUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pricePerUnitController.dispose();
    _pricePerPacketController.dispose();
    _packetSizeController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _validate() {
    final name = _nameController.text.trim();
    final ppu = double.tryParse(_pricePerUnitController.text.trim());
    final qty = int.tryParse(_quantityController.text.trim());
    setState(() {
      _nameError = name.isEmpty ? 'Drug name is required' : null;
      _pricePerUnitError = ppu == null || ppu <= 0 ? 'Enter a valid price per unit' : null;
      _quantityError = qty == null || qty < 0 ? 'Quantity must be 0 or greater' : null;
    });
  }

  Future<void> _pickImage() async {
    if (kIsWeb) {
      final input = html.FileUploadInputElement()
        ..accept = 'image/*';
      input.click();

      await input.onChange.first;
      if (input.files != null && input.files!.isNotEmpty) {
        final file = input.files!.first;
        final reader = html.FileReader();
        reader.readAsArrayBuffer(file);
        await reader.onLoad.first;
        final bytes = Uint8List.fromList(reader.result as List<int>);
        if (bytes.isNotEmpty) {
          setState(() {
            _pickedImageBytes = bytes;
            _pickedImageName = file.name;
            _imageRemoved = false;
          });
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not read image data. Try a different image.')),
            );
          }
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image upload is only supported on web.')),
        );
      }
    }
  }

  void _removeImage() {
    setState(() {
      _pickedImageBytes = null;
      _pickedImageName = null;
      _existingImageUrl = null;
      _imageRemoved = true;
    });
  }

  Future<String?> _uploadImageToCloudinary() async {
    if (_pickedImageBytes == null) return _existingImageUrl;

    setState(() => _uploadingImage = true);
    try {
      const cloudName = 'dng9zqvk5';
      const uploadPreset = 'pharmafinder';
      final url = 'https://api.cloudinary.com/v1_1/$cloudName/image/upload';

      final formData = html.FormData()
        ..appendBlob('file', html.Blob([_pickedImageBytes!]), _pickedImageName ?? 'image.jpg')
        ..append('upload_preset', uploadPreset)
        ..append('folder', 'drug_images');

      final request = await html.HttpRequest.request(
        url,
        method: 'POST',
        sendData: formData,
        requestHeaders: {'Accept': 'application/json'},
      );

      final response = json.decode(request.responseText!);
      if (response['secure_url'] != null) {
        return response['secure_url'] as String;
      } else {
        final errorMsg = response['error']?['message'] ?? 'Unknown error';
        throw Exception(errorMsg);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image upload failed: $e')),
        );
      }
      return null;
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<void> _save() async {
    _validate();
    if (_nameError != null || _pricePerUnitError != null || _quantityError != null) return;
    setState(() => _saving = true);

    String? imageUrl = _existingImageUrl;
    if (_pickedImageBytes != null) {
      imageUrl = await _uploadImageToCloudinary();
    } else if (_imageRemoved) {
      imageUrl = null;
    }

    final map = <String, dynamic>{
      'name': _nameController.text.trim(),
      'pricePerUnit': double.parse(_pricePerUnitController.text.trim()),
      'unitLabel': _unitLabel,
      'quantity': int.parse(_quantityController.text.trim()),
      'category': _category,
      'expiryDate': _expiryDate?.toIso8601String(),
      'imageUrl': imageUrl,
    };
    if (_hasPacketPricing) {
      final pp = double.tryParse(_pricePerPacketController.text.trim());
      final ps = int.tryParse(_packetSizeController.text.trim());
      if (pp != null && pp > 0) map['pricePerPacket'] = pp;
      if (ps != null && ps > 0) map['packetSize'] = ps;
    } else {
      map['pricePerPacket'] = null;
      map['packetSize'] = null;
    }
    await widget.onSave(map);
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _pickExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _expiryDate = picked);
  }

  Widget _buildImagePicker() {
    final hasExistingImage = _existingImageUrl != null && !_imageRemoved;
    final hasNewImage = _pickedImageBytes != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasExistingImage && !hasNewImage) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              _existingImageUrl!,
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, e, s) => Container(
                height: 120,
                color: AppColors.surfaceContainerLow,
                child: const Center(
                  child: Text('Could not load image',
                      style: TextStyle(color: AppColors.onSurfaceVariant)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _uploadingImage ? null : _pickImage,
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: const Text('Replace Image'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _uploadingImage ? null : _removeImage,
                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                label: const Text('Remove', style: TextStyle(color: AppColors.error)),
              ),
            ],
          ),
        ] else if (hasNewImage) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              _pickedImageBytes!,
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _uploadingImage ? null : _pickImage,
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: const Text('Change Image'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _uploadingImage ? null : _removeImage,
                icon: const Icon(Icons.close, size: 18, color: AppColors.error),
                label: const Text('Remove', style: TextStyle(color: AppColors.error)),
              ),
            ],
          ),
        ] else ...[
          OutlinedButton(
            onPressed: _uploadingImage ? null : _pickImage,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 28),
              side: const BorderSide(color: AppColors.outlineVariant),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _uploadingImage
                ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      ),
                      SizedBox(height: 8),
                      Text('Uploading...', style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant)),
                    ],
                  )
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined, size: 32, color: AppColors.onSurfaceVariant),
                      SizedBox(height: 6),
                      Text('Tap to upload an image', style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant)),
                    ],
                  ),
          ),
        ],
      ],
    );
  }

  static const _defaultUnitLabels = [
    'unit', 'tablet', 'capsule', 'bottle', 'sachet', 'strip', 'pack', 'box', 'vial',
  ];

  @override
  Widget build(BuildContext context) {
    final existingCategories =
        widget.categories.where((c) => c != 'All Categories').toList();
    final allCategories = ['Antibiotics', 'Pain Relief', 'Cardiology', 'Diabetes', 'Vitamins', 'Other']
        .where((c) => !existingCategories.contains(c)).toList();
    final categoryOptions = ['', ...existingCategories, ...allCategories];
    if (_category.isNotEmpty && !categoryOptions.contains(_category)) {
      categoryOptions.add(_category);
    }

    final unitOptions = List<String>.from(_defaultUnitLabels);
    if (_unitLabel.isNotEmpty && !unitOptions.contains(_unitLabel)) {
      unitOptions.add(_unitLabel);
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 500,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.outlineVariant),
          boxShadow: [
            BoxShadow(color: AppColors.primary.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_isEditing ? 'Edit Drug' : 'Add Drug',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    color: AppColors.onSurfaceVariant,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel('DRUG NAME', required: true),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(hintText: 'e.g. Paracetamol', errorText: _nameError),
                      onChanged: (_) => setState(() => _nameError = null),
                    ),
                    const SizedBox(height: 20),
                    Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          _FieldLabel('CATEGORY'),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: _category.isEmpty ? null : _category,
                            decoration: const InputDecoration(hintText: 'Select category'),
                            items: categoryOptions.where((c) => c.isNotEmpty).map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                            onChanged: (v) => setState(() => _category = v ?? ''),
                          ),
                        ]),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          _FieldLabel('UNIT LABEL'),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: _unitLabel,
                            decoration: const InputDecoration(hintText: 'e.g. unit, pack'),
                            items: unitOptions
                                .map((u) => DropdownMenuItem(
                                      value: u,
                                      child: Text(
                                          u[0].toUpperCase() + u.substring(1)),
                                    ))
                                .toList(),
                            onChanged: (v) => setState(() => _unitLabel = v ?? 'unit'),
                          ),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 20),
                    _FieldLabel('PRICE PER UNIT (FCFA)', required: true),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _pricePerUnitController,
                      decoration: InputDecoration(
                        hintText: '0',
                        errorText: _pricePerUnitError,
                        suffixIcon: const Padding(
                          padding: EdgeInsets.only(right: 16),
                          child: Text('FCFA',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, fontFamily: 'monospace', color: AppColors.onSurfaceVariant)),
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() => _pricePerUnitError = null),
                    ),
                    const SizedBox(height: 16),
                    Row(children: [
                      Checkbox(
                        value: _hasPacketPricing,
                        onChanged: (v) => setState(() => _hasPacketPricing = v ?? false),
                        activeColor: AppColors.primary,
                      ),
                      const Text('Add packet pricing', style: TextStyle(fontSize: 14, color: AppColors.onSurface)),
                    ]),
                    if (_hasPacketPricing) ...[
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            _FieldLabel('PRICE PER PACKET (FCFA)'),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _pricePerPacketController,
                              decoration: const InputDecoration(hintText: '0'),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ]),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            _FieldLabel('UNITS PER PACKET'),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _packetSizeController,
                              decoration: const InputDecoration(hintText: 'e.g. 10'),
                              keyboardType: TextInputType.number,
                            ),
                          ]),
                        ),
                      ]),
                    ],
                    const SizedBox(height: 20),
                    _FieldLabel('QUANTITY', required: true),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _quantityController,
                      decoration: InputDecoration(hintText: '0', errorText: _quantityError),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() => _quantityError = null),
                    ),
                    const SizedBox(height: 20),
                    _FieldLabel('EXPIRY DATE'),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: _pickExpiryDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.outlineVariant),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _expiryDate != null
                                  ? '${_expiryDate!.day}/${_expiryDate!.month}/${_expiryDate!.year}'
                                  : 'Not set',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: _expiryDate != null ? AppColors.onSurface : AppColors.onSurfaceVariant),
                            ),
                            const Icon(Icons.calendar_today, size: 18, color: AppColors.onSurfaceVariant),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _FieldLabel('DRUG IMAGE (optional)'),
                    const SizedBox(height: 6),
                    _buildImagePicker(),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_isEditing ? 'Save Changes' : 'Save'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// RESTOCK DIALOG
// =============================================================================

class _RestockDialog extends StatefulWidget {
  final Drug drug;
  final Future<void> Function(int unitQty, double? unitPrice, int packetQty, double? packetPrice) onRestock;
  const _RestockDialog({required this.drug, required this.onRestock});
  @override
  State<_RestockDialog> createState() => _RestockDialogState();
}

class _RestockDialogState extends State<_RestockDialog> {
  final _unitQtyController = TextEditingController();
  final _unitPriceController = TextEditingController();
  final _packetQtyController = TextEditingController();
  final _packetPriceController = TextEditingController();
  bool _updatingUnitPrice = false;
  bool _updatingPacketPrice = false;
  bool _saving = false;
  String? _error;

  bool get _hasPacketPricing => widget.drug.pricePerPacket != null;

  @override
  void dispose() {
    _unitQtyController.dispose();
    _unitPriceController.dispose();
    _packetQtyController.dispose();
    _packetPriceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final unitQty = int.tryParse(_unitQtyController.text.trim()) ?? 0;
    final packetQty = int.tryParse(_packetQtyController.text.trim()) ?? 0;
    final unitPrice = _updatingUnitPrice
        ? double.tryParse(_unitPriceController.text.trim())
        : null;
    final packetPrice = _updatingPacketPrice && _hasPacketPricing
        ? double.tryParse(_packetPriceController.text.trim())
        : null;

    if (unitQty == 0 && packetQty == 0) {
      setState(() => _error = 'Enter a quantity to restock');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    await widget.onRestock(unitQty, unitPrice, packetQty, packetPrice);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.drug;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 440,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Restock',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
                      const SizedBox(height: 2),
                      Text(d.name,
                          style: const TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    color: AppColors.onSurfaceVariant,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Current stock:',
                              style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant)),
                          Text('${d.quantity} ${d.unitLabel}s',
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Unit restock
                    _FieldLabel('ADD BY UNIT'),
                    const SizedBox(height: 6),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _unitQtyController,
                          decoration: InputDecoration(
                            hintText: 'Qty',
                            errorText: _error,
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() => _error = null),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${d.unitLabel}s', style: const TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant)),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Checkbox(
                        value: _updatingUnitPrice,
                        onChanged: (v) => setState(() => _updatingUnitPrice = v ?? false),
                        activeColor: AppColors.primary,
                      ),
                      const Text('Update unit price',
                          style: TextStyle(fontSize: 13, color: AppColors.onSurface)),
                    ]),
                    if (_updatingUnitPrice) ...[
                      TextField(
                        controller: _unitPriceController,
                        decoration: InputDecoration(
                          hintText: 'New price per unit (FCFA)',
                          prefixText: 'FCFA ',
                          prefixStyle: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700, fontFamily: 'monospace', color: AppColors.onSurfaceVariant),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ],
                    if (_hasPacketPricing) ...[
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 12),
                      _FieldLabel('ADD BY PACKET'),
                      const SizedBox(height: 6),
                      Row(children: [
                        Expanded(
                          child: TextField(
                            controller: _packetQtyController,
                            decoration: const InputDecoration(hintText: 'Qty'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('packets (${d.packetSize} ${d.unitLabel}s each)',
                            style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Checkbox(
                          value: _updatingPacketPrice,
                          onChanged: (v) => setState(() => _updatingPacketPrice = v ?? false),
                          activeColor: AppColors.primary,
                        ),
                        const Text('Update packet price',
                            style: TextStyle(fontSize: 13, color: AppColors.onSurface)),
                      ]),
                      if (_updatingPacketPrice)
                        TextField(
                          controller: _packetPriceController,
                          decoration: const InputDecoration(
                            hintText: 'New price per packet (FCFA)',
                            prefixText: 'FCFA ',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Restock'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// SELL DIALOG
// =============================================================================

class _SellDialog extends StatefulWidget {
  final Drug drug;
  final CollectionReference transactionsRef;
  const _SellDialog({required this.drug, required this.transactionsRef});
  @override
  State<_SellDialog> createState() => _SellDialogState();
}

class _SellDialogState extends State<_SellDialog> {
  final _qtyController = TextEditingController();
  bool _saving = false;
  String? _error;

  Drug get _drug => widget.drug;

  double get _total {
    final qty = int.tryParse(_qtyController.text.trim()) ?? 0;
    return qty * _drug.pricePerUnit;
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  Future<void> _confirmSale() async {
    final qty = int.tryParse(_qtyController.text.trim());
    if (qty == null || qty <= 0) {
      setState(() => _error = 'Enter a valid quantity');
      return;
    }
    if (qty > _drug.quantity) {
      setState(() => _error = 'Not enough stock (${_drug.quantity} available)');
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.transactionsRef.add({
        'drugId': _drug.reference!.id,
        'drugName': _drug.name,
        'quantitySold': qty,
        'pricePerUnit': _drug.pricePerUnit,
        'totalAmount': qty * _drug.pricePerUnit,
        'unitLabel': _drug.unitLabel,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await _drug.reference!.update({
        'quantity': FieldValue.increment(-qty),
      });

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Sold $qty ${_drug.unitLabel}${qty > 1 ? 's' : ''} of ${_drug.name}'),
            backgroundColor: AppColors.secondary,
          ),
        );
        nav.pop();
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Sale failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 400,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Sell Drug',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
                      const SizedBox(height: 2),
                      Text(_drug.name,
                          style: const TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    color: AppColors.onSurfaceVariant,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Available stock:',
                              style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant)),
                          Text('${_drug.quantity} ${_drug.unitLabel}s',
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Unit price:',
                              style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant)),
                          Text('${_drug.pricePerUnit.toStringAsFixed(0)} FCFA',
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'monospace', color: AppColors.onSurface)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _FieldLabel('QUANTITY TO SELL', required: true),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _qtyController,
                      decoration: InputDecoration(
                        hintText: '0',
                        errorText: _error,
                        suffixText: '${_drug.unitLabel}s',
                      ),
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      onChanged: (_) => setState(() => _error = null),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total:',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
                          Text('${_total.toStringAsFixed(0)} FCFA',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'monospace', color: AppColors.primary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _confirmSale,
                    icon: _saving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.shopping_cart_outlined, size: 18),
                    label: const Text('Confirm Sale'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// FIELD LABEL
// =============================================================================

class _FieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  const _FieldLabel(this.text, {this.required = false});
  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        text: '$text ',
        style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: AppColors.onSurfaceVariant),
        children: required
            ? const [TextSpan(text: '*', style: TextStyle(color: AppColors.error))]
            : null,
      ),
    );
  }
}
