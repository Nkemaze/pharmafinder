import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'admin/admin_dashboard_page.dart';
import 'dashboard_page.dart';
import 'profile_setup_page.dart';

enum _Role { admin, pharmacy, unregistered }

/// Routes an authenticated user to the correct experience:
///   - administrator  -> AdminDashboardPage
///   - pharmacy       -> MainShell (or forced ProfileSetupPage)
///   - unknown user   -> ProfileSetupPage (creates the pharmacy profile)
class AuthGate extends StatefulWidget {
  final User user;
  const AuthGate({super.key, required this.user});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  _Role? _role;

  @override
  void initState() {
    super.initState();
    _resolveRole();
  }

  Future<void> _resolveRole() async {
    final db = FirebaseFirestore.instance;
    final uid = widget.user.uid;
    try {
      final adminDoc = await db.collection('admins').doc(uid).get();
      if (adminDoc.exists) {
        if (mounted) setState(() => _role = _Role.admin);
        return;
      }
      final pharmacyDoc = await db.collection('pharmacies').doc(uid).get();
      if (mounted) {
        setState(() =>
            _role = pharmacyDoc.exists ? _Role.pharmacy : _Role.unregistered);
      }
    } catch (_) {
      if (mounted) {
        setState(() =>
            _role = _Role.unregistered);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = _role;
    if (role == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    switch (role) {
      case _Role.admin:
        return AdminDashboardPage(user: widget.user);
      case _Role.pharmacy:
        return _buildPharmacyGate();
      case _Role.unregistered:
        return ProfileSetupPage(user: widget.user);
    }
  }

  Widget _buildPharmacyGate() {
    final db = FirebaseFirestore.instance;
    final uid = widget.user.uid;
    return StreamBuilder<DocumentSnapshot>(
      stream: db.collection('pharmacies').doc(uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body:
                Center(child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final status = data?['status'] as String? ?? 'active';
        if (status == 'suspended' || status == 'deleted') {
          return _BlockedScreen(status: status, email: widget.user.email);
        }
        final needsSetup = data == null || data['mustUpdateProfile'] == true;
        if (needsSetup) return ProfileSetupPage(user: widget.user);
        return const MainShell();
      },
    );
  }
}

/// Shown when a pharmacy account has been suspended or deleted by the admin.
class _BlockedScreen extends StatelessWidget {
  final String status;
  final String? email;
  const _BlockedScreen({required this.status, required this.email});

  @override
  Widget build(BuildContext context) {
    final isDeleted = status == 'deleted';
    return Scaffold(
      body: Center(
        child: Container(
          width: 440,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.errorContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.block,
                    color: AppColors.error, size: 36),
              ),
              const SizedBox(height: 20),
              Text(
                isDeleted ? 'Account Deactivated' : 'Account Suspended',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                email ?? '',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isDeleted
                    ? 'This pharmacy account has been deactivated by the administrator. Please contact support if you believe this is a mistake.'
                    : 'This pharmacy account has been suspended by the administrator. Please contact support if you believe this is a mistake.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  child: const Text('Sign Out'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
