import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../services/pharmacy_hours.dart';

class StoreStatusContent extends StatefulWidget {
  const StoreStatusContent({super.key});
  @override
  State<StoreStatusContent> createState() => _StoreStatusContentState();
}

class _StoreStatusContentState extends State<StoreStatusContent> {
  String get _pharmacyId => FirebaseAuth.instance.currentUser!.uid;
  DocumentReference get _pharmacyRef =>
      FirebaseFirestore.instance.collection('pharmacies').doc(_pharmacyId);

  bool _toggling = false;

  /// Writes the manual open/closed override. The full `hours` map is written
  /// (schedule + flag) because the customer app prefers the nested `hours`
  /// map when it exists.
  Future<void> _setStoreOpen(bool open, Map<String, dynamic> data) async {
    setState(() => _toggling = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _pharmacyRef.update({
        'hours': {
          'weekdayOpen': data['weekdayOpen'],
          'weekdayClose': data['weekdayClose'],
          'weekendOpen': data['weekendOpen'],
          'weekendClose': data['weekendClose'],
          '_manualOpen': open,
        },
      });
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error updating store status: $e')),
      );
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  /// Removes the manual override so the schedule decides the status again.
  Future<void> _resetToSchedule() async {
    setState(() => _toggling = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _pharmacyRef.update({
        'hours._manualOpen': FieldValue.delete(),
      });
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error updating store status: $e')),
      );
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _pharmacyRef.snapshots(),
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

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final isOpen = data != null && data.isNotEmpty
            ? PharmacyHours.isOpenNow(data)
            : false;
        final hasOverride =
            data != null && PharmacyHours.hasManualOverride(data);
        final avgOpenHours = data?['avgOpenHours']?.toString() ?? '—';
        final activityLevel = data?['activityLevel']?.toString() ?? '—';
        final trustScore = data?['trustScore']?.toString() ?? '—';

        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(40),
            child: Column(
              children: [
                // Header
                const Text(
                  'Pharmacy Operations',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Update your store availability for the PharmaFinder network.',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 48),
                // Central card
                Container(
                  width: 700,
                  padding: const EdgeInsets.all(48),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.outlineVariant.withValues(alpha: 0.1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Pharmacy icon
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surfaceContainerLow,
                        ),
                        child: const Icon(
                          Icons.local_pharmacy_rounded,
                          size: 48,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'Is this pharmacy currently open?',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        decoration: BoxDecoration(
                          color: isOpen
                              ? AppColors.secondaryContainer
                              : AppColors.errorContainer,
                          borderRadius: BorderRadius.circular(40),
                          boxShadow: [
                            BoxShadow(
                              color: (isOpen ? AppColors.secondary : AppColors.error)
                                  .withValues(alpha: 0.1),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isOpen ? AppColors.secondary : AppColors.error,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              isOpen ? 'Currently Open' : 'Currently Closed',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: isOpen ? AppColors.secondary : AppColors.error,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Patients can see your status in real-time. Please ensure accuracy to maintain delivery reliability.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Manual status toggle
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.outlineVariant
                                .withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Manual status control',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    hasOverride
                                        ? 'Manual override is active. Reset to follow your schedule.'
                                        : 'Overrides your schedule so you can open or close early.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.onSurfaceVariant
                                          .withValues(alpha: 0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (hasOverride)
                              TextButton(
                                onPressed:
                                    _toggling ? null : _resetToSchedule,
                                child: const Text('Reset to schedule'),
                              ),
                            Switch(
                              value: isOpen,
                              onChanged: _toggling
                                  ? null
                                  : (v) => _setStoreOpen(v, data ?? const {}),
                              activeThumbColor: AppColors.secondary,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Hours schedule
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'SCHEDULE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.8,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _HoursRow(
                              label: 'Weekdays',
                              open: data?['weekdayOpen']?.toString() ?? '—',
                              close: data?['weekdayClose']?.toString() ?? '—',
                            ),
                            const SizedBox(height: 10),
                            _HoursRow(
                              label: 'Weekends',
                              open: data?['weekendOpen']?.toString() ?? '—',
                              close: data?['weekendClose']?.toString() ?? '—',
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Edit schedule in Pharmacy Profile',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // Mini stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _MiniStat(Icons.schedule_rounded, 'Avg Open Time', '$avgOpenHours Hours'),
                    const SizedBox(width: 24),
                    _MiniStat(Icons.analytics_outlined, 'Activity Level', activityLevel),
                    const SizedBox(width: 24),
                    _MiniStat(Icons.verified_outlined, 'Trust Score', '$trustScore% Verified'),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HoursRow extends StatelessWidget {
  final String label;
  final String open;
  final String close;
  const _HoursRow({required this.label, required this.open, required this.close});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.onSurface),
          ),
        ),
        Text(
          '$open — $close',
          style: const TextStyle(fontSize: 13, fontFamily: 'monospace', color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _MiniStat(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
