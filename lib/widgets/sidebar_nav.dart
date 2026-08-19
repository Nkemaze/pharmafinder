import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SidebarNav extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final VoidCallback? onLogout;

  const SidebarNav({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    this.onLogout,
  });

  static const _navItems = [
    _NavItem(icon: Icons.dashboard_rounded, label: 'Dashboard'),
    _NavItem(icon: Icons.medication_rounded, label: 'Manage Drugs'),
    _NavItem(icon: Icons.storefront_rounded, label: 'Store Status'),
    _NavItem(icon: Icons.local_pharmacy_rounded, label: 'Pharmacy Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 256,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLow,
        border: Border(
          right: BorderSide(color: AppColors.outlineVariant),
        ),
      ),
      child: Column(
        children: [
          // Logo
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
                      'INVENTORY CONTROL',
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
          // Navigation
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: List.generate(_navItems.length, (index) {
                final item = _navItems[index];
                final isSelected = selectedIndex == index;
                return _NavTile(
                  item: item,
                  isSelected: isSelected,
                  onTap: () => onItemSelected(index),
                );
              }),
            ),
          ),
          const Spacer(),
          // Settings & Logout
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: Container(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.outlineVariant),
                ),
              ),
              child: Column(
                children: [
                  const _NavTile(
                    item: _NavItem(icon: Icons.settings_rounded, label: 'Settings'),
                    isSelected: false,
                  ),
                  _NavTile(
                    item: const _NavItem(icon: Icons.logout_rounded, label: 'Logout'),
                    isSelected: false,
                    onTap: onLogout,
                    isDestructive: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

class _NavTile extends StatelessWidget {
  final _NavItem item;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool isDestructive;

  const _NavTile({
    required this.item,
    required this.isSelected,
    this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? AppColors.error
        : isSelected
            ? AppColors.primary
            : AppColors.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
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
                Icon(item.icon, size: 22, color: color),
                const SizedBox(width: 12),
                Text(
                  item.label,
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
