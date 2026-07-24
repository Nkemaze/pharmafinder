import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_theme.dart';
import 'location_picker_page.dart';

class PharmacyProfilePage extends StatefulWidget {
  const PharmacyProfilePage({super.key});
  @override
  State<PharmacyProfilePage> createState() => _PharmacyProfilePageState();
}

class _PharmacyProfilePageState extends State<PharmacyProfilePage> {
  final _nameController = TextEditingController();
  final _licenseController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _emergencyDescController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final MapController _mapController = MapController();

  // Store hours as TimeOfDay pairs
  TimeOfDay _weekdayOpen = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _weekdayClose = const TimeOfDay(hour: 20, minute: 0);
  TimeOfDay _weekendOpen = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _weekendClose = const TimeOfDay(hour: 15, minute: 0);

  LatLng? _selectedLocation;
  bool _isSaving = false;
  bool _isLoaded = false;
  String? _loadError;
  bool _showSuccess = false;
  DateTime? _updatedAt;

  String get _pharmacyId => FirebaseAuth.instance.currentUser!.uid;
  DocumentReference get _pharmacyRef =>
      FirebaseFirestore.instance.collection('pharmacies').doc(_pharmacyId);

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _licenseController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    _emergencyPhoneController.dispose();
    _emergencyDescController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final snapshot = await _pharmacyRef.get();
      final data = snapshot.data() as Map<String, dynamic>?;
      if (data != null) {
        _nameController.text = data['name'] ?? '';
        _addressController.text = data['address'] ?? '';
        _licenseController.text = data['license'] ?? '';
        _emailController.text =
            data['email'] ?? FirebaseAuth.instance.currentUser?.email ?? '';
        _cityController.text = data['city'] ?? '';
        _stateController.text = data['state'] ?? '';
        _zipController.text = data['zip'] ?? '';
        _emergencyPhoneController.text = data['emergencyPhone'] ?? '';
        _emergencyDescController.text = data['emergencyDesc'] ?? '';

        if (data['weekdayOpen'] != null) {
          _weekdayOpen = _parseTimeOfDay(data['weekdayOpen']);
        }
        if (data['weekdayClose'] != null) {
          _weekdayClose = _parseTimeOfDay(data['weekdayClose']);
        }
        if (data['weekendOpen'] != null) {
          _weekendOpen = _parseTimeOfDay(data['weekendOpen']);
        }
        if (data['weekendClose'] != null) {
          _weekendClose = _parseTimeOfDay(data['weekendClose']);
        }

        if (data['latitude'] != null && data['longitude'] != null) {
          _selectedLocation = LatLng(
              (data['latitude'] as num).toDouble(),
              (data['longitude'] as num).toDouble());
        }
        if (data['updatedAt'] != null && data['updatedAt'] is Timestamp) {
          _updatedAt = (data['updatedAt'] as Timestamp).toDate();
        }
      }
    } catch (e) {
      setState(() => _loadError = 'Failed to load profile: $e');
    } finally {
      setState(() => _isLoaded = true);
    }
  }

  TimeOfDay _parseTimeOfDay(String value) {
    final parts = value.split(':');
    if (parts.length == 2) {
      return TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 0,
          minute: int.tryParse(parts[1]) ?? 0);
    }
    return const TimeOfDay(hour: 0, minute: 0);
  }

  String _formatTimeOfDay(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _pickTime({required bool isWeekday, required bool isOpen}) async {
    final current = isWeekday
        ? (isOpen ? _weekdayOpen : _weekdayClose)
        : (isOpen ? _weekendOpen : _weekendClose);

    final picked = await showTimePicker(
      context: context,
      initialTime: current,
    );
    if (picked != null) {
      setState(() {
        if (isWeekday) {
          if (isOpen) {
            _weekdayOpen = picked;
          } else {
            _weekdayClose = picked;
          }
        } else {
          if (isOpen) {
            _weekendOpen = picked;
          } else {
            _weekendClose = picked;
          }
        }
      });
    }
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => LocationPickerPage(initialLocation: _selectedLocation),
      ),
    );
    if (result != null) {
      setState(() => _selectedLocation = result);
      // Move map to new location
      Future.microtask(() {
        if (mounted) _mapController.move(result, 15);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await _pharmacyRef.set({
        'name': _nameController.text.trim(),
        'address': _addressController.text.trim(),
        'license': _licenseController.text.trim(),
        'email': _emailController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'zip': _zipController.text.trim(),
        'weekdayOpen': _formatTimeOfDay(_weekdayOpen),
        'weekdayClose': _formatTimeOfDay(_weekdayClose),
        'weekendOpen': _formatTimeOfDay(_weekendOpen),
        'weekendClose': _formatTimeOfDay(_weekendClose),
        'emergencyPhone': _emergencyPhoneController.text.trim(),
        'emergencyDesc': _emergencyDescController.text.trim(),
        if (_selectedLocation != null) ...{
          'latitude': _selectedLocation!.latitude,
          'longitude': _selectedLocation!.longitude,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          _showSuccess = true;
          _updatedAt = DateTime.now();
        });
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _showSuccess = false);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour = dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} at ${hour == 0 ? 12 : hour}:$min $ampm';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: 16),
            Text(_loadError!, style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _loadError = null;
                  _isLoaded = false;
                });
                _loadProfile();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

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
                  Text(
                    'ACCOUNT SETTINGS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Pharmacy Profile',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              if (_showSuccess)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(
                        color: AppColors.secondary.withValues(alpha: 0.2)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle,
                          size: 20, color: AppColors.secondary),
                      SizedBox(width: 8),
                      Text(
                        'Profile saved successfully',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 32),
          Form(
            key: _formKey,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 7,
                  child: Column(
                    children: [
                      _Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.info_outline,
                                    size: 22, color: AppColors.primary),
                                const SizedBox(width: 12),
                                const Text(
                                  'General Information',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.onSurface,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: _FormField(
                                    label: 'PHARMACY NAME',
                                    child: TextFormField(
                                      controller: _nameController,
                                      decoration:
                                          const InputDecoration(hintText: ''),
                                      validator: (v) => (v == null ||
                                              v.trim().isEmpty)
                                          ? 'Required'
                                          : null,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _FormField(
                                    label: 'LICENSE NUMBER',
                                    child: TextField(
                                        controller: _licenseController),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _FormField(
                              label: 'CONTACT EMAIL',
                              child: TextField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _FormField(
                              label: 'STREET ADDRESS',
                              child: TextFormField(
                                controller: _addressController,
                                decoration:
                                    const InputDecoration(hintText: ''),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Required'
                                        : null,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _FormField(
                                    label: 'CITY',
                                    child: TextField(
                                        controller: _cityController),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _FormField(
                                    label: 'STATE',
                                    child: TextField(
                                        controller: _stateController),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _FormField(
                                    label: 'ZIP CODE',
                                    child: TextField(
                                        controller: _zipController),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: _Card(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'STORE HOURS',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _TimePickerRow(
                                    label: 'WEEKDAYS',
                                    openTime: _weekdayOpen,
                                    closeTime: _weekdayClose,
                                    onOpenTap: () => _pickTime(
                                        isWeekday: true, isOpen: true),
                                    onCloseTap: () => _pickTime(
                                        isWeekday: true, isOpen: false),
                                  ),
                                  const SizedBox(height: 12),
                                  _TimePickerRow(
                                    label: 'WEEKENDS',
                                    openTime: _weekendOpen,
                                    closeTime: _weekendClose,
                                    onOpenTap: () => _pickTime(
                                        isWeekday: false, isOpen: true),
                                    onCloseTap: () => _pickTime(
                                        isWeekday: false, isOpen: false),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _Card(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'EMERGENCY CONTACT',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _FormField(
                                    label: 'PHONE',
                                    child: TextField(
                                      controller: _emergencyPhoneController,
                                      keyboardType: TextInputType.phone,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _FormField(
                                    label: 'DESCRIPTION',
                                    child: TextField(
                                      controller: _emergencyDescController,
                                      decoration: const InputDecoration(
                                          hintText:
                                              'e.g. Direct line to duty pharmacist'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      _Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_outlined,
                                        size: 22, color: AppColors.primary),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Location',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    if (_selectedLocation != null)
                                      TextButton(
                                        onPressed: _pickLocation,
                                        child: const Text('Change',
                                            style: TextStyle(
                                                color: AppColors.primary)),
                                      ),
                                    TextButton(
                                      onPressed: () =>
                                          setState(() => _selectedLocation = null),
                                      child: const Text('Reset',
                                          style: TextStyle(
                                              color: AppColors.primary)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              height: 300,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.outlineVariant
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: _selectedLocation != null
                                  ? Stack(
                                      children: [
                                        FlutterMap(
                                          mapController: _mapController,
                                          options: MapOptions(
                                            initialCenter: _selectedLocation!,
                                            initialZoom: 15,
                                            interactionOptions:
                                                const InteractionOptions(
                                              flags: InteractiveFlag.all &
                                                  ~InteractiveFlag.rotate,
                                            ),
                                          ),
                                          children: [
                                            TileLayer(
                                              urlTemplate:
                                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                              userAgentPackageName:
                                                  'com.example.pharmacy',
                                            ),
                                            MarkerLayer(
                                              markers: [
                                                Marker(
                                                  point: _selectedLocation!,
                                                  width: 40,
                                                  height: 40,
                                                  child: const Icon(
                                                    Icons.location_pin,
                                                    color: AppColors.primary,
                                                    size: 40,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        // Coordinates overlay
                                        Positioned(
                                          bottom: 8,
                                          left: 8,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.white
                                                  .withValues(alpha: 0.9),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '${_selectedLocation!.latitude.toStringAsFixed(4)}, ${_selectedLocation!.longitude.toStringAsFixed(4)}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontFamily: 'monospace',
                                                fontWeight: FontWeight.w500,
                                                color: AppColors.onSurface,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Center(
                                      child: ElevatedButton.icon(
                                        onPressed: _pickLocation,
                                        icon: const Icon(Icons.near_me),
                                        label: const Text('Pick Location on Map'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: AppColors.onSurface,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 24, vertical: 16),
                                        ),
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _selectedLocation != null
                                  ? 'Used for logistics calculation and nearest-delivery routing.'
                                  : 'Tap the button above to set your pharmacy location.',
                              style: const TextStyle(
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _saveProfile,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save_outlined, size: 22),
                          label: Text(
                            _isSaving ? 'Syncing Profile...' : 'Save Profile',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 4,
                            shadowColor:
                                AppColors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _updatedAt != null
                            ? 'Last updated: ${_formatDate(_updatedAt!)}'
                            : 'Profile not yet saved',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// TIME PICKER ROW
// =============================================================================

class _TimePickerRow extends StatelessWidget {
  final String label;
  final TimeOfDay openTime;
  final TimeOfDay closeTime;
  final VoidCallback onOpenTap;
  final VoidCallback onCloseTap;

  const _TimePickerRow({
    required this.label,
    required this.openTime,
    required this.closeTime,
    required this.onOpenTap,
    required this.onCloseTap,
  });

  String _formatTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: onOpenTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatTime(openTime),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'monospace',
                      color: AppColors.onSurface,
                    ),
                  ),
                  const Icon(Icons.access_time,
                      size: 18, color: AppColors.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'to',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: onCloseTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatTime(closeTime),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'monospace',
                      color: AppColors.onSurface,
                    ),
                  ),
                  const Icon(Icons.access_time,
                      size: 18, color: AppColors.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// HELPER WIDGETS
// =============================================================================

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppColors.outlineVariant.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _FormField extends StatelessWidget {
  final String label;
  final Widget child;
  const _FormField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}
