import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import '../../theme/app_theme.dart';

/// Administrator dashboard shell: overview + pharmacy management.
class AdminDashboardPage extends StatefulWidget {
  final User user;
  const AdminDashboardPage({super.key, required this.user});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int _index = 0;

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Row(
        children: [
          _AdminSidebar(
            selectedIndex: _index,
            onItemSelected: (i) => setState(() => _index = i),
            onLogout: _logout,
          ),
          Expanded(
            child: Column(
              children: [
                _AdminTopBar(
                  title: _index == 0 ? 'Administrator Overview' : 'Manage Pharmacies',
                  email: widget.user.email ?? 'Administrator',
                ),
                Expanded(
                  child: _index == 0
                      ? _OverviewTab(
                          onViewAll: () => setState(() => _index = 1))
                      : const _PharmaciesTab(),
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
// SIDEBAR
// =============================================================================

class _AdminSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final VoidCallback onLogout;

  const _AdminSidebar({
    required this.selectedIndex,
    required this.onItemSelected,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 256,
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLow,
        border: Border(right: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Row(
              children: [
                Image.asset(
                  'assets/images/icon.png',
                  width: 32,
                  height: 32,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PharmaFinder',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'ADMIN CONSOLE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurfaceVariant,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _SidebarItem(
            icon: Icons.dashboard_rounded,
            label: 'Overview',
            isSelected: selectedIndex == 0,
            onTap: () => onItemSelected(0),
          ),
          _SidebarItem(
            icon: Icons.local_pharmacy_rounded,
            label: 'Pharmacies',
            isSelected: selectedIndex == 1,
            onTap: () => onItemSelected(1),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.outlineVariant)),
              ),
              child: _SidebarItem(
                icon: Icons.logout_rounded,
                label: 'Logout',
                isSelected: false,
                destructive: true,
                onTap: onLogout,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool destructive;
  final VoidCallback? onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    this.destructive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? AppColors.error
        : isSelected
            ? AppColors.primary
            : AppColors.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
      child: Material(
        color: isSelected
            ? AppColors.secondaryContainer.withValues(alpha: 0.2)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 22, color: color),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// TOP BAR
// =============================================================================

class _AdminTopBar extends StatelessWidget {
  final String title;
  final String email;
  const _AdminTopBar({required this.title, required this.email});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 40),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shield_outlined,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
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
// OVERVIEW TAB
// =============================================================================

class _OverviewTab extends StatelessWidget {
  final VoidCallback onViewAll;
  const _OverviewTab({required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('pharmacies').snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final pharmacies = docs.map((d) {
          final data = d.data() as Map<String, dynamic>;
          return _PharmacyRow.fromDoc(d.id, data);
        }).toList();

        final total = pharmacies.length;
        final pending =
            pharmacies.where((p) => p.mustUpdateProfile).length;
        final active =
            pharmacies.where((p) => p.status == 'active').length;
        final suspended =
            pharmacies.where((p) => p.status == 'suspended').length;
        final deleted =
            pharmacies.where((p) => p.status == 'deleted').length;

        final recent = pharmacies.where((p) => p.status != 'deleted').toList()
          ..sort((a, b) => (b.createdAt ?? DateTime(0))
              .compareTo(a.createdAt ?? DateTime(0)));
        final recentList = recent.take(6).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'WELCOME BACK, ADMIN',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Platform Overview',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  _OverviewStat(
                    icon: Icons.local_pharmacy_rounded,
                    label: 'Total Pharmacies',
                    value: '$total',
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 24),
                  _OverviewStat(
                    icon: Icons.pending_actions_rounded,
                    label: 'Pending Setup',
                    value: '$pending',
                    color: AppColors.tertiary,
                  ),
                  const SizedBox(width: 24),
                  _OverviewStat(
                    icon: Icons.check_circle_outline,
                    label: 'Active',
                    value: '$active',
                    color: AppColors.secondary,
                  ),
                  const SizedBox(width: 24),
                  _OverviewStat(
                    icon: Icons.pause_circle_outline,
                    label: 'Suspended',
                    value: '$suspended',
                    color: AppColors.error,
                  ),
                  const SizedBox(width: 24),
                  _OverviewStat(
                    icon: Icons.delete_outline,
                    label: 'Deleted',
                    value: '$deleted',
                    color: AppColors.outline,
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.outlineVariant.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent Pharmacies',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurface,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: onViewAll,
                          icon: const Icon(Icons.arrow_forward, size: 18),
                          label: const Text('View all'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (recentList.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'No pharmacies yet. Create your first pharmacy in the Pharmacies tab.',
                            style: TextStyle(color: AppColors.onSurfaceVariant),
                          ),
                        ),
                      )
                    else
                      Column(
                        children: [
                          for (int i = 0; i < recentList.length; i++) ...[
                            if (i > 0)
                              const Divider(height: 1, indent: 48),
                            _RecentRow(pharmacy: recentList[i]),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OverviewStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _OverviewStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 26),
                const SizedBox(width: 8),
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  final _PharmacyRow pharmacy;
  const _RecentRow({required this.pharmacy});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.local_pharmacy_rounded,
                size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pharmacy.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                  ),
                ),
                Text(
                  pharmacy.email,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          _StatusBadge(status: pharmacy.status, pending: pharmacy.mustUpdateProfile),
        ],
      ),
    );
  }
}

// =============================================================================
// PHARMACIES TAB
// =============================================================================

class _PharmaciesTab extends StatefulWidget {
  const _PharmaciesTab();

  @override
  State<_PharmaciesTab> createState() => _PharmaciesTabState();
}

class _PharmaciesTabState extends State<_PharmaciesTab> {
  final _service = AdminService();
  String _search = '';
  String _statusFilter = 'All';

  static const _filters = [
    'All',
    'Active',
    'Pending Setup',
    'Suspended',
    'Deleted',
  ];

  Future<void> _openAddDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const _AddPharmacyDialog(),
    );
    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pharmacy account created. Send the credentials to the pharmacy — they will be required to set up their profile and a new password on first login.',
          ),
          backgroundColor: AppColors.secondary,
        ),
      );
    }
  }

  Future<void> _resetPassword(_PharmacyRow p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset password'),
        content: Text(
            'A password-reset link will be emailed to ${p.email}. They can use it to set a new password. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Send reset email'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.sendPasswordResetEmail(p.email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Password reset email sent to ${p.email}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send reset email: $e')),
        );
      }
    }
  }

  Future<void> _toggleStatus(_PharmacyRow p) async {
    try {
      if (p.status == 'deleted') {
        await _service.setPharmacyStatus(p.uid, 'active');
      } else if (p.status == 'active') {
        await _service.setPharmacyStatus(p.uid, 'suspended');
      } else {
        await _service.setPharmacyStatus(p.uid, 'active');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e')),
        );
      }
    }
  }

  Future<void> _delete(_PharmacyRow p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete pharmacy'),
        content: Text(
            'Deactivate "${p.name}" (${p.email})? The pharmacy will no longer be able to sign in. This can be undone from the Deleted filter.'),
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
    if (confirmed != true) return;
    try {
      await _service.deletePharmacy(p.uid);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('pharmacies').snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final all = docs
            .map((d) =>
                _PharmacyRow.fromDoc(d.id, d.data() as Map<String, dynamic>))
            .toList();

        List<_PharmacyRow> filtered = all;
        if (_search.isNotEmpty) {
          final q = _search.toLowerCase();
          filtered = filtered
              .where((p) =>
                  p.name.toLowerCase().contains(q) ||
                  p.email.toLowerCase().contains(q))
              .toList();
        }
        switch (_statusFilter) {
          case 'Active':
            filtered =
                filtered.where((p) => p.status == 'active').toList();
          case 'Pending Setup':
            filtered =
                filtered.where((p) => p.mustUpdateProfile).toList();
          case 'Suspended':
            filtered =
                filtered.where((p) => p.status == 'suspended').toList();
          case 'Deleted':
            filtered =
                filtered.where((p) => p.status == 'deleted').toList();
        }
        filtered.sort((a, b) => (b.createdAt ?? DateTime(0))
            .compareTo(a.createdAt ?? DateTime(0)));

        return SingleChildScrollView(
          padding: const EdgeInsets.all(40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pharmacies',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Create and manage pharmacy accounts across the PharmaFinder network.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _openAddDialog,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Pharmacy'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  SizedBox(
                    width: 360,
                    height: 40,
                    child: TextField(
                      onChanged: (v) => setState(() => _search = v),
                      decoration: InputDecoration(
                        hintText: 'Search by name or email...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'Status: ',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        DropdownButton<String>(
                          value: _statusFilter,
                          underline: const SizedBox(),
                          isDense: true,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                          items: _filters
                              .map((f) =>
                                  DropdownMenuItem(value: f, child: Text(f)))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _statusFilter = v ?? 'All'),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${filtered.length} of ${all.length} pharmacies',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.outlineVariant.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(12)),
                        border: Border(
                          bottom: BorderSide(color: AppColors.outlineVariant),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Expanded(
                              flex: 3,
                              child: _TableHeader('PHARMACY')),
                          Expanded(flex: 3, child: _TableHeader('EMAIL')),
                          Expanded(flex: 2, child: _TableHeader('STATUS')),
                          Expanded(flex: 2, child: _TableHeader('CREATED')),
                          Expanded(flex: 2, child: _TableHeader('ACTIONS')),
                        ],
                      ),
                    ),
                    if (filtered.isEmpty)
                      const SizedBox(
                        height: 200,
                        child: Center(
                          child: Text(
                            'No pharmacies match the current filter.',
                            style: TextStyle(color: AppColors.onSurfaceVariant),
                          ),
                        ),
                      )
                    else
                      for (int i = 0; i < filtered.length; i++) ...[
                        if (i > 0)
                          const Divider(height: 1, indent: 16, endIndent: 16),
                        _PharmacyTableRow(
                          pharmacy: filtered[i],
                          onResetPassword: () =>
                              _resetPassword(filtered[i]),
                          onToggleStatus: () =>
                              _toggleStatus(filtered[i]),
                          onDelete: () => _delete(filtered[i]),
                        ),
                      ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TableHeader extends StatelessWidget {
  final String text;
  const _TableHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: AppColors.onSurfaceVariant,
      ),
    );
  }
}

class _PharmacyTableRow extends StatelessWidget {
  final _PharmacyRow pharmacy;
  final VoidCallback onResetPassword;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;

  const _PharmacyTableRow({
    required this.pharmacy,
    required this.onResetPassword,
    required this.onToggleStatus,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final deleted = pharmacy.status == 'deleted';
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.local_pharmacy_rounded,
                      size: 18, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    pharmacy.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              pharmacy.email,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.onSurface,
              ),
            ),
          ),
          Expanded(flex: 2, child: _StatusBadge(status: pharmacy.status, pending: pharmacy.mustUpdateProfile)),
          Expanded(
            flex: 2,
            child: Text(
              _formatDate(pharmacy.createdAt),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Tooltip(
                  message: deleted
                      ? 'Restore pharmacy'
                      : pharmacy.status == 'active'
                          ? 'Suspend pharmacy'
                          : 'Activate pharmacy',
                  child: InkWell(
                    onTap: onToggleStatus,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        deleted
                            ? Icons.restore_from_trash_outlined
                            : pharmacy.status == 'active'
                                ? Icons.pause_circle_outline
                                : Icons.play_circle_outline,
                        size: 18,
                        color: pharmacy.status == 'active'
                            ? AppColors.error
                            : AppColors.secondary,
                      ),
                    ),
                  ),
                ),
                Tooltip(
                  message: 'Reset password',
                  child: InkWell(
                    onTap: deleted ? null : onResetPassword,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.key_outlined,
                        size: 18,
                        color: deleted
                            ? AppColors.outlineVariant
                            : AppColors.tertiary,
                      ),
                    ),
                  ),
                ),
                if (!deleted)
                  Tooltip(
                    message: 'Delete',
                    child: InkWell(
                      onTap: onDelete,
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: const Icon(Icons.delete_outline,
                            size: 18, color: AppColors.error),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final bool pending;
  const _StatusBadge({required this.status, required this.pending});

  @override
  Widget build(BuildContext context) {
    final (label, color, bg) = status == 'deleted'
        ? ('Deleted', AppColors.outline, AppColors.surfaceContainerHigh)
        : pending
            ? ('Pending Setup', AppColors.tertiary, AppColors.tertiaryFixed)
            : status == 'suspended'
                ? ('Suspended', AppColors.error, AppColors.errorContainer)
                : ('Active', AppColors.secondary,
                    AppColors.secondaryContainer);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// =============================================================================
// ADD PHARMACY DIALOG
// =============================================================================

class _AddPharmacyDialog extends StatefulWidget {
  const _AddPharmacyDialog();

  @override
  State<_AddPharmacyDialog> createState() => _AddPharmacyDialogState();
}

class _AddPharmacyDialogState extends State<_AddPharmacyDialog> {
  final _service = AdminService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  String? _error;

  static const _chars =
      'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';

  void _generatePassword() {
    final random = Random.secure();
    final password =
        List.generate(10, (_) => _chars[random.nextInt(_chars.length)]).join();
    setState(() => _passwordController.text = password);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _service.createPharmacyAccount(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on AdminSetupException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Failed to create account: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 480,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add Pharmacy',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Create a pharmacy account with temporary credentials',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _FieldLabel('PHARMACY NAME', required: true),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameController,
                        decoration:
                            const InputDecoration(hintText: 'e.g. City Care Pharmacy'),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Pharmacy name is required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      const _FieldLabel('EMAIL ADDRESS', required: true),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                            hintText: 'pharmacy@pharmafinder.com'),
                        validator: (v) =>
                            (v == null || !v.contains('@'))
                                ? 'Enter a valid email'
                                : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _FieldLabel('TEMPORARY PASSWORD',
                                    required: true),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscure,
                                  decoration: InputDecoration(
                                    hintText: 'min. 6 characters',
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscure
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        size: 20,
                                        color: AppColors.outline,
                                      ),
                                      onPressed: () => setState(
                                          () => _obscure = !_obscure),
                                    ),
                                  ),
                                  validator: (v) =>
                                      (v == null || v.length < 6)
                                          ? 'At least 6 characters'
                                          : null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(top: 24),
                            child: OutlinedButton.icon(
                              onPressed: _generatePassword,
                              icon: const Icon(Icons.casino_outlined, size: 18),
                              label: const Text('Generate'),
                            ),
                          ),
                        ],
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.error),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'After creation, share the email and temporary password with the pharmacy. On their first login they will be required to update their profile and set a new password.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
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
                    onPressed: _saving ? null : _create,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.person_add_alt, size: 18),
                    label: const Text('Create Account'),
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
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: AppColors.onSurfaceVariant,
        ),
        children: required
            ? const [TextSpan(text: '*', style: TextStyle(color: AppColors.error))]
            : null,
      ),
    );
  }
}

// =============================================================================
// ROW MODEL
// =============================================================================

class _PharmacyRow {
  final String uid;
  final String name;
  final String email;
  final String status;
  final bool mustUpdateProfile;
  final DateTime? createdAt;

  const _PharmacyRow({
    required this.uid,
    required this.name,
    required this.email,
    required this.status,
    required this.mustUpdateProfile,
    this.createdAt,
  });

  factory _PharmacyRow.fromDoc(String id, Map<String, dynamic> data) {
    DateTime? created;
    if (data['createdAt'] is Timestamp) {
      created = (data['createdAt'] as Timestamp).toDate();
    }
    return _PharmacyRow(
      uid: id,
      name: data['name'] ?? 'Unnamed pharmacy',
      email: data['email'] ?? '—',
      status: data['status'] as String? ?? 'active',
      mustUpdateProfile: data['mustUpdateProfile'] == true,
      createdAt: created,
    );
  }
}
