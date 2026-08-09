import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../models/drug.dart';
import '../services/connectivity_service.dart';
import '../services/pharmacy_hours.dart';
import '../widgets/sidebar_nav.dart';
import '../widgets/top_nav_bar.dart';
import 'drug_management_page.dart';
import 'store_status_page.dart';
import 'pharmacy_profile_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  final GlobalKey<_DashboardContentState> _dashboardKey = GlobalKey();
  final ConnectivityService _connectivity = ConnectivityService();
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _isOnline = _connectivity.isOnline;
    _connectivity.isConnected.listen((online) {
      if (mounted) setState(() => _isOnline = online);
    });
  }

  @override
  void dispose() {
    _connectivity.dispose();
    super.dispose();
  }

  void _onNavItemSelected(int index) {
    setState(() => _selectedIndex = index);
    if (index == 0) {
      _dashboardKey.currentState?.refresh();
    }
  }

  Widget _buildPage() {
    switch (_selectedIndex) {
      case 0:
        return DashboardContent(
          key: _dashboardKey,
          onNavigate: _onNavItemSelected,
        );
      case 1:
        return const DrugManagementPage();
      case 2:
        return const StoreStatusContent();
      case 3:
        return const PharmacyProfilePage();
      default:
        return DashboardContent(
          key: _dashboardKey,
          onNavigate: _onNavItemSelected,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Row(
        children: [
          SidebarNav(
            selectedIndex: _selectedIndex,
            onItemSelected: _onNavItemSelected,
            onLogout: () => FirebaseAuth.instance.signOut(),
          ),
          Expanded(
            child: Column(
              children: [
                TopNavBar(title: '', isOnline: _isOnline),
                Expanded(child: _buildPage()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// DASHBOARD CONTENT — ALL DATA FROM FIRESTORE
// =============================================================================

class DashboardContent extends StatefulWidget {
  final void Function(int)? onNavigate;
  const DashboardContent({super.key, this.onNavigate});

  @override
  State<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<DashboardContent> {
  String get _pharmacyId => FirebaseAuth.instance.currentUser!.uid;
  DocumentReference get _pharmacyRef =>
      FirebaseFirestore.instance.collection('pharmacies').doc(_pharmacyId);
  CollectionReference get _drugsRef =>
      _pharmacyRef.collection('drugs');

  void refresh() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _pharmacyRef.snapshots(),
      builder: (context, pharmacySnap) {
        final pharmacyData =
            pharmacySnap.data?.data() as Map<String, dynamic>? ?? {};
        final pharmacyName = pharmacyData['name'] ?? 'Pharmacy';
        final isOpen = PharmacyHours.isOpenNow(pharmacyData);

        return StreamBuilder<QuerySnapshot>(
          stream: _drugsRef.snapshots(),
          builder: (context, drugsSnap) {
            final docs = drugsSnap.data?.docs ?? [];
            final drugs = docs
                .map((d) => Drug.fromMap(
                    d.id, d.data() as Map<String, dynamic>,
                    reference: d.reference))
                .toList();

            final totalDrugs = drugs.length;
            final lowStock =
                drugs.where((d) => d.quantity > 0 && d.quantity <= 10).toList();
            final outOfStock = drugs.where((d) => d.quantity == 0).toList();
            final lowAndOutCount = lowStock.length + outOfStock.length;
            final totalValue =
                drugs.fold<double>(0, (acc, d) => acc + d.price * d.quantity);

            final now = DateTime.now();
            final expiringSoon = drugs.where((d) {
              if (d.expiryDate == null) return false;
              final daysLeft = d.expiryDate!.difference(now).inDays;
              return daysLeft >= 0 && daysLeft <= 30;
            }).toList();

            final alerts = <_AlertItem>[];
            for (final d in outOfStock.take(2)) {
              alerts.add(_AlertItem(
                  drug: d.name, detail: 'Out of Stock', action: 'ORDER'));
            }
            for (final d in lowStock.take(2 - alerts.length)) {
              alerts.add(_AlertItem(
                  drug: d.name,
                  detail: 'Only ${d.quantity} units left',
                  action: 'ORDER'));
            }
            for (final d in expiringSoon.take(3 - alerts.length)) {
              final daysLeft = d.expiryDate!.difference(now).inDays;
              alerts.add(_AlertItem(
                  drug: d.name,
                  detail: 'Expiring in $daysLeft days',
                  action: 'DISPOSE'));
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(pharmacyName, isOpen),
                  const SizedBox(height: 40),
                  _buildStatsRow(
                      isOpen, totalDrugs, lowAndOutCount, totalValue),
                  const SizedBox(height: 24),
                  _buildBottomSection(
                      drugs, lowStock, outOfStock, expiringSoon, alerts),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(String pharmacyName, bool isOpen) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? user?.email?.split('@').first ?? 'User';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CENTRAL HUB',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Welcome back, $displayName',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              pharmacyName,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 18, color: AppColors.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  _formatDate(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'SYSTEM LIVE: SYNC ACTIVE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsRow(
      bool isOpen, int totalDrugs, int lowAndOutCount, double totalValue) {
    final lastUpdateText = 'Live';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: _StatCard(
            color: AppColors.primaryContainer,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Icon(Icons.storefront_rounded,
                        color: AppColors.onPrimaryContainer, size: 32),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isOpen ? AppColors.secondary : AppColors.error,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isOpen
                                ? Icons.check_circle_rounded
                                : Icons.cancel_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isOpen ? 'OPEN' : 'CLOSED',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Store Operational Status',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isOpen
                      ? 'Your pharmacy is currently visible to all patients and logistics partners.'
                      : 'Your pharmacy is currently hidden from patients and logistics partners.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CURRENT MODE',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onPrimaryContainer,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isOpen ? 'Priority Filling' : 'Offline',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 7,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _SmallStatCard(
                      icon: Icons.inventory_2_outlined,
                      iconBg: AppColors.surfaceContainerHigh,
                      iconColor: AppColors.primary,
                      label: 'Total Drugs',
                      value: _formatNumber(totalDrugs),
                      badge: '$totalDrugs SKUs',
                      badgeColor: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _SmallStatCard(
                      icon: Icons.warning_amber_rounded,
                      iconBg: AppColors.errorContainer,
                      iconColor: AppColors.error,
                      label: 'Low / Out Stock',
                      value: '$lowAndOutCount',
                      badge: lowAndOutCount > 0 ? 'Attention needed' : 'All clear',
                      badgeColor: lowAndOutCount > 0 ? AppColors.error : AppColors.secondary,
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _SmallStatCard(
                      icon: Icons.update_rounded,
                      iconBg: AppColors.tertiaryFixed,
                      iconColor: AppColors.tertiary,
                      label: 'Last Update',
                      value: lastUpdateText,
                      badge: 'Auto-Sync',
                      badgeColor: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomSection(
    List<Drug> drugs,
    List<Drug> lowStock,
    List<Drug> outOfStock,
    List<Drug> expiringSoon,
    List<_AlertItem> alerts,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 8,
          child: Column(
            children: [
              _ChartCard(drugs: drugs),
              const SizedBox(height: 24),
              _ActivityCard(drugs: drugs),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 4,
          child: Column(
            children: [
              _QuickActionsCard(
                drugs: drugs,
                pharmacyId: _pharmacyId,
                onNavigate: widget.onNavigate,
              ),
              const SizedBox(height: 24),
              _AlertsCard(alerts: alerts),
            ],
          ),
        ),
      ],
    );
  }

  static String _formatDate() {
    final now = DateTime.now();
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday'
    ];
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  static String _formatNumber(int n) {
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(1)}k';
    }
    return '$n';
  }
}

// =============================================================================
// HELPER WIDGETS
// =============================================================================

class _AlertItem {
  final String drug;
  final String detail;
  final String action;
  const _AlertItem(
      {required this.drug, required this.detail, required this.action});
}

class _StatCard extends StatelessWidget {
  final Color color;
  final Widget child;
  const _StatCard({required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
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

class _SmallStatCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String value;
  final String badge;
  final Color badgeColor;

  const _SmallStatCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.badge,
    required this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 22, color: iconColor),
              ),
              Text(
                badge,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: badgeColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurface,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final List<Drug> drugs;
  const _ChartCard({required this.drugs});

  @override
  Widget build(BuildContext context) {
    final Map<String, int> categoryQty = {};
    for (final d in drugs) {
      final cat = d.category.isEmpty ? 'Uncategorized' : d.category;
      categoryQty[cat] = (categoryQty[cat] ?? 0) + d.quantity;
    }

    final entries = categoryQty.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(7).toList();
    final maxQty = top.isEmpty ? 1 : top.first.value;

    final heights =
        top.map((e) => (e.value / maxQty).toDouble()).toList();
    final labels = top.map((e) => e.key.toUpperCase()).toList();

    if (heights.isEmpty) {
      heights.addAll([0.0]);
      labels.add('NO DATA');
    }

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Inventory Flow',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
              Row(
                children: [
                  _ChartToggle(label: 'By Category', isActive: true),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: heights.map((h) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FractionallySizedBox(
                      heightFactor: h,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: labels
                .take(7)
                .map((d) => Expanded(
                      child: Text(
                        d,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _ChartToggle extends StatelessWidget {
  final String label;
  final bool isActive;
  const _ChartToggle({required this.label, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? AppColors.primary : AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isActive ? Colors.white : AppColors.onSurface,
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final List<Drug> drugs;
  const _ActivityCard({required this.drugs});

  @override
  Widget build(BuildContext context) {
    final activityItems = <_ActivityEntry>[];

    final outOfStock = drugs.where((d) => d.quantity == 0).toList();
    for (final d in outOfStock.take(2)) {
      activityItems.add(_ActivityEntry(
        icon: Icons.warning_amber_rounded,
        iconBg: AppColors.errorContainer,
        iconColor: AppColors.error,
        title: '${d.name} — Out of Stock',
        subtitle: 'Quantity is 0, reorder required',
        badge: 'ALERT',
        badgeBg: AppColors.errorContainer,
        badgeColor: AppColors.error,
      ));
    }

    final lowStock =
        drugs.where((d) => d.quantity > 0 && d.quantity <= 10).toList();
    for (final d in lowStock.take(2)) {
      activityItems.add(_ActivityEntry(
        icon: Icons.inventory_outlined,
        iconBg: AppColors.tertiaryFixed,
        iconColor: AppColors.tertiary,
        title: '${d.name} — Low Stock',
        subtitle: 'Only ${d.quantity} units remaining',
        badge: 'LOW STOCK',
        badgeBg: AppColors.surfaceContainerHighest,
        badgeColor: AppColors.onSurfaceVariant,
      ));
    }

    final now = DateTime.now();
    final expiring = drugs.where((d) {
      if (d.expiryDate == null) return false;
      final days = d.expiryDate!.difference(now).inDays;
      return days >= 0 && days <= 30;
    }).toList();
    for (final d in expiring.take(2)) {
      final days = d.expiryDate!.difference(now).inDays;
      activityItems.add(_ActivityEntry(
        icon: Icons.event_busy_rounded,
        iconBg: AppColors.errorContainer,
        iconColor: AppColors.error,
        title: '${d.name} — Expiring Soon',
        subtitle: 'Expires in $days days',
        badge: 'EXPIRY',
        badgeBg: AppColors.errorContainer,
        badgeColor: AppColors.error,
      ));
    }

    if (activityItems.isEmpty) {
      activityItems.add(_ActivityEntry(
        icon: Icons.check_circle_outline,
        iconBg: AppColors.secondaryContainer,
        iconColor: AppColors.secondary,
        title: 'All Clear',
        subtitle: 'No critical inventory issues found',
        badge: 'OK',
        badgeBg: AppColors.secondaryContainer,
        badgeColor: AppColors.onSecondaryContainer,
      ));
    }

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(
                  bottom:
                      BorderSide(color: AppColors.outlineVariant)),
            ),
            child: const Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
              ),
            ),
          ),
          for (int i = 0; i < activityItems.take(4).length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 72),
            _ActivityRow(entry: activityItems[i]),
          ],
        ],
      ),
    );
  }
}

class _ActivityEntry {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeBg;
  final Color badgeColor;

  const _ActivityEntry({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeBg,
    required this.badgeColor,
  });
}

class _ActivityRow extends StatelessWidget {
  final _ActivityEntry entry;
  const _ActivityRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: entry.iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(entry.icon, size: 20, color: entry.iconColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: entry.badgeBg,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              entry.badge,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: entry.badgeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  final List<Drug> drugs;
  final String pharmacyId;
  final void Function(int)? onNavigate;

  const _QuickActionsCard({
    required this.drugs,
    required this.pharmacyId,
    this.onNavigate,
  });

  void _onSellTap(BuildContext context) {
    if (drugs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No drugs in inventory. Add a drug first.')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (_) => _QuickSellDialog(
        drugs: drugs,
        pharmacyId: pharmacyId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'QUICK COMMANDS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.2,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _QuickAction(
                icon: Icons.add_circle_outline,
                label: 'Add Drug',
                onTap: () => onNavigate?.call(1),
              ),
              _QuickAction(
                icon: Icons.shopping_cart_outlined,
                label: 'Sell Drug',
                color: AppColors.tertiary,
                onTap: () => _onSellTap(context),
              ),
              _QuickAction(
                icon: Icons.published_with_changes_outlined,
                label: 'Update Status',
                onTap: () => onNavigate?.call(2),
              ),
              _QuickAction(
                icon: Icons.person_outline,
                label: 'Edit Profile',
                onTap: () => onNavigate?.call(3),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;

  const _QuickAction({
    required this.icon,
    required this.label,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? AppColors.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: iconColor),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: onTap != null ? AppColors.onSurface : AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// QUICK SELL DIALOG (from dashboard shortcut)
// =============================================================================

class _QuickSellDialog extends StatefulWidget {
  final List<Drug> drugs;
  final String pharmacyId;
  const _QuickSellDialog({required this.drugs, required this.pharmacyId});
  @override
  State<_QuickSellDialog> createState() => _QuickSellDialogState();
}

class _QuickSellDialogState extends State<_QuickSellDialog> {
  Drug? _selectedDrug;
  final _qtyController = TextEditingController();
  bool _saving = false;
  String? _error;
  String _searchQuery = '';

  CollectionReference get _transactionsRef => FirebaseFirestore.instance
      .collection('pharmacies')
      .doc(widget.pharmacyId)
      .collection('transactions');

  List<Drug> get _filteredDrugs {
    if (_searchQuery.isEmpty) return widget.drugs;
    return widget.drugs
        .where((d) => d.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  double get _total {
    if (_selectedDrug == null) return 0;
    final qty = int.tryParse(_qtyController.text.trim()) ?? 0;
    return qty * _selectedDrug!.pricePerUnit;
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  Future<void> _confirmSale() async {
    if (_selectedDrug == null) {
      setState(() => _error = 'Select a drug');
      return;
    }
    final qty = int.tryParse(_qtyController.text.trim());
    if (qty == null || qty <= 0) {
      setState(() => _error = 'Enter a valid quantity');
      return;
    }
    if (qty > _selectedDrug!.quantity) {
      setState(() => _error = 'Not enough stock (${_selectedDrug!.quantity} available)');
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await _transactionsRef.add({
        'drugId': _selectedDrug!.reference!.id,
        'drugName': _selectedDrug!.name,
        'quantitySold': qty,
        'pricePerUnit': _selectedDrug!.pricePerUnit,
        'totalAmount': qty * _selectedDrug!.pricePerUnit,
        'unitLabel': _selectedDrug!.unitLabel,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await _selectedDrug!.reference!.update({
        'quantity': FieldValue.increment(-qty),
      });

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Sold $qty ${_selectedDrug!.unitLabel}${qty > 1 ? 's' : ''} of ${_selectedDrug!.name}'),
            backgroundColor: AppColors.secondary,
          ),
        );
        nav.pop();
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Sale failed: $e')));
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
        width: 440,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
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
                  const Text('Quick Sell',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
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
                    const Text('SELECT DRUG',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: AppColors.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search drugs...',
                        prefixIcon: Icon(Icons.search, size: 20),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 180),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.outlineVariant),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _filteredDrugs.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: Text('No drugs found', style: TextStyle(color: AppColors.onSurfaceVariant)),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: _filteredDrugs.length,
                              itemBuilder: (ctx, i) {
                                final drug = _filteredDrugs[i];
                                final isSelected = _selectedDrug?.name == drug.name;
                                return ListTile(
                                  dense: true,
                                  selected: isSelected,
                                  selectedTileColor: AppColors.primary.withValues(alpha: 0.08),
                                  leading: Icon(
                                    Icons.medication_rounded,
                                    size: 20,
                                    color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
                                  ),
                                  title: Text(drug.name,
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                          color: isSelected ? AppColors.primary : AppColors.onSurface)),
                                  subtitle: Text(
                                    '${drug.pricePerUnit.toStringAsFixed(0)} FCFA/unit  •  ${drug.quantity} ${drug.unitLabel}s',
                                    style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                                  ),
                                  trailing: isSelected
                                      ? const Icon(Icons.check_circle, size: 18, color: AppColors.primary)
                                      : null,
                                  onTap: () => setState(() {
                                    _selectedDrug = drug;
                                    _error = null;
                                  }),
                                );
                              },
                            ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.error)),
                    ],
                    if (_selectedDrug != null) ...[
                      const SizedBox(height: 20),
                      const Text('QUANTITY',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: AppColors.onSurfaceVariant)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _qtyController,
                        decoration: InputDecoration(
                          hintText: '0',
                          suffixText: '${_selectedDrug!.unitLabel}s',
                        ),
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        onChanged: (_) => setState(() => _error = null),
                      ),
                      const SizedBox(height: 16),
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
                    onPressed: (_saving || _selectedDrug == null) ? null : _confirmSale,
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

class _AlertsCard extends StatelessWidget {
  final List<_AlertItem> alerts;
  const _AlertsCard({required this.alerts});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.errorContainer.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppColors.error.withValues(alpha: 0.15)),
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
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 20, color: AppColors.error),
              const SizedBox(width: 8),
              const Text(
                'CRITICAL INVENTORY ALERTS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (alerts.isEmpty)
            const Text(
              'No critical alerts',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.onSurfaceVariant,
              ),
            )
          else
            for (int i = 0; i < alerts.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _AlertRow(
                  drug: alerts[i].drug,
                  detail: alerts[i].detail,
                  action: alerts[i].action),
            ],
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  final String drug;
  final String detail;
  final String action;
  const _AlertRow(
      {required this.drug, required this.detail, required this.action});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: AppColors.error.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  drug,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.error),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              action,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
