import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_theme.dart';
import 'location_picker_page.dart';

/// Forced onboarding screen shown when a pharmacy has not yet set up its
/// profile and password (created by the admin with temporary credentials).
///
/// The AuthGate only shows this page while `mustUpdateProfile == true`, so the
/// pharmacy cannot reach the main dashboard until both sections are completed.
class ProfileSetupPage extends StatefulWidget {
  final User user;
  const ProfileSetupPage({super.key, required this.user});

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _licenseController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _emergencyDescController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final MapController _mapController = MapController();

  TimeOfDay _weekdayOpen = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _weekdayClose = const TimeOfDay(hour: 20, minute: 0);
  TimeOfDay _weekendOpen = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _weekendClose = const TimeOfDay(hour: 15, minute: 0);

  LatLng? _selectedLocation;
  bool _isSaving = false;
  bool _isLoaded = false;
  String? _errorMessage;

  DocumentReference get _pharmacyRef => FirebaseFirestore.instance
      .collection('pharmacies')
      .doc(widget.user.uid);

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.user.email ?? '';
    _loadExisting();
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
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    try {
      final snapshot = await _pharmacyRef.get();
      final data = snapshot.data() as Map<String, dynamic>?;
      if (data != null) {
        _nameController.text = data['name'] ?? '';
        _licenseController.text = data['license'] ?? '';
        _emailController.text =
            data['email'] ?? widget.user.email ?? '';
        _addressController.text = data['address'] ?? '';
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
            (data['longitude'] as num).toDouble(),
          );
        }
      }
    } catch (_) {
      // Non-fatal: setup still works with an empty profile.
    } finally {
      if (mounted) setState(() => _isLoaded = true);
    }
  }

  TimeOfDay _parseTimeOfDay(String value) {
    final parts = value.split(':');
    if (parts.length == 2) {
      return TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 0,
        minute: int.tryParse(parts[1]) ?? 0,
      );
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
    final picked = await showTimePicker(context: context, initialTime: current);
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
      Future.microtask(() {
        if (mounted) _mapController.move(result, 15);
      });
    }
  }

  Future<void> _completeSetup() async {
    if (!_formKey.currentState!.validate()) return;
    final user = widget.user;
    final email = user.email ?? _emailController.text.trim();

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      // 1) Change the password (reauth with the temporary password first).
      final credential = EmailAuthProvider.credential(
        email: email,
        password: _currentPasswordController.text,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(_newPasswordController.text.trim());

      // 2) Save the pharmacy profile and lift the forced-setup flag.
      await _pharmacyRef.set({
        'name': _nameController.text.trim(),
        'license': _licenseController.text.trim(),
        'email': _emailController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'zip': _zipController.text.trim(),
        'weekdayOpen': _formatTimeOfDay(_weekdayOpen),
        'weekdayClose': _formatTimeOfDay(_weekdayClose),
        'weekendOpen': _formatTimeOfDay(_weekendOpen),
        'weekendClose': _formatTimeOfDay(_weekendClose),
        // Keep the nested hours map (read by the customer app) in sync.
        // Dot paths preserve any existing `hours._manualOpen` override.
        'hours.weekdayOpen': _formatTimeOfDay(_weekdayOpen),
        'hours.weekdayClose': _formatTimeOfDay(_weekdayClose),
        'hours.weekendOpen': _formatTimeOfDay(_weekendOpen),
        'hours.weekendClose': _formatTimeOfDay(_weekendClose),
        'emergencyPhone': _emergencyPhoneController.text.trim(),
        'emergencyDesc': _emergencyDescController.text.trim(),
        if (_selectedLocation != null) ...{
          'latitude': _selectedLocation!.latitude,
          'longitude': _selectedLocation!.longitude,
        },
        'mustUpdateProfile': false,
        'profileCompletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile saved. Welcome to PharmaFinder!'),
            backgroundColor: AppColors.secondary,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.code == 'invalid-credential'
            ? 'Current password is incorrect.'
            : (e.message ?? 'Failed to update password.');
      });
    } catch (e) {
      setState(() => _errorMessage = 'Failed to complete setup: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
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
                          'ACCOUNT SETUP REQUIRED',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                            color: AppColors.primary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Complete Your Pharmacy Profile',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurface,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Your administrator created this account. Please set your profile details and choose a new password to continue.',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: () => FirebaseAuth.instance.signOut(),
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('Sign out'),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                if (_errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.report, color: AppColors.error, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
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
                                  const _SectionTitle(
                                      icon: Icons.info_outline,
                                      title: 'General Information'),
                                  const SizedBox(height: 20),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _FormField(
                                          label: 'PHARMACY NAME *',
                                          child: TextFormField(
                                            controller: _nameController,
                                            validator: (v) =>
                                                (v == null || v.trim().isEmpty)
                                                    ? 'Required'
                                                    : null,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: _FormField(
                                          label: 'LICENSE NUMBER',
                                          child: TextFormField(
                                              controller: _licenseController),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  _FormField(
                                    label: 'CONTACT EMAIL *',
                                    child: TextFormField(
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      validator: (v) =>
                                          (v == null || !v.contains('@'))
                                              ? 'Enter a valid email'
                                              : null,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _FormField(
                                    label: 'STREET ADDRESS *',
                                    child: TextFormField(
                                      controller: _addressController,
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
                                          child: TextFormField(
                                              controller: _cityController),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: _FormField(
                                          label: 'STATE',
                                          child: TextFormField(
                                              controller: _stateController),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: _FormField(
                                          label: 'ZIP CODE',
                                          child: TextFormField(
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const _SectionTitle(
                                            icon: Icons.schedule,
                                            title: 'Store Hours'),
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
                                              isWeekday: false,
                                              isOpen: false),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _Card(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const _SectionTitle(
                                            icon: Icons.local_hospital_outlined,
                                            title: 'Emergency Contact'),
                                        const SizedBox(height: 16),
                                        _FormField(
                                          label: 'PHONE',
                                          child: TextFormField(
                                            controller:
                                                _emergencyPhoneController,
                                            keyboardType: TextInputType.phone,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        _FormField(
                                          label: 'DESCRIPTION',
                                          child: TextFormField(
                                            controller:
                                                _emergencyDescController,
                                            decoration:
                                                const InputDecoration(
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
                                  const _SectionTitle(
                                      icon: Icons.lock_outline,
                                      title: 'Set New Password',
                                      trailing: _RequiredBadge()),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'You must change the temporary password provided by your administrator.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _FormField(
                                    label: 'CURRENT PASSWORD *',
                                    child: TextFormField(
                                      controller: _currentPasswordController,
                                      obscureText: true,
                                      validator: (v) =>
                                          (v == null || v.isEmpty)
                                              ? 'Required'
                                              : null,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  _FormField(
                                    label: 'NEW PASSWORD *',
                                    child: TextFormField(
                                      controller: _newPasswordController,
                                      obscureText: true,
                                      validator: (v) {
                                        if (v == null || v.isEmpty) {
                                          return 'Required';
                                        }
                                        if (v.length < 6) {
                                          return 'At least 6 characters';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  _FormField(
                                    label: 'CONFIRM NEW PASSWORD *',
                                    child: TextFormField(
                                      controller: _confirmPasswordController,
                                      obscureText: true,
                                      validator: (v) {
                                        if (v !=
                                            _newPasswordController.text) {
                                          return 'Passwords do not match';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            _Card(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const _SectionTitle(
                                      icon: Icons.location_on_outlined,
                                      title: 'Pharmacy Location'),
                                  const SizedBox(height: 16),
                                  Container(
                                    height: 220,
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
                                                  initialCenter:
                                                      _selectedLocation!,
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
                                                        point:
                                                            _selectedLocation!,
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
                                            ],
                                          )
                                        : Center(
                                            child: ElevatedButton.icon(
                                              onPressed: _pickLocation,
                                              icon: const Icon(Icons.near_me),
                                              label: const Text(
                                                  'Pick Location on Map'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.white,
                                                foregroundColor:
                                                    AppColors.onSurface,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 24,
                                                        vertical: 14),
                                              ),
                                            ),
                                          ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _selectedLocation != null
                                            ? '${_selectedLocation!.latitude.toStringAsFixed(4)}, ${_selectedLocation!.longitude.toStringAsFixed(4)}'
                                            : 'Optional but recommended for delivery routing.',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.onSurfaceVariant,
                                        ),
                                      ),
                                      if (_selectedLocation != null)
                                        TextButton(
                                          onPressed: () => setState(() =>
                                              _selectedLocation = null),
                                          child: const Text('Clear'),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton.icon(
                                onPressed: _isSaving ? null : _completeSetup,
                                icon: _isSaving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.check_circle_outline,
                                        size: 22),
                                label: Text(
                                  _isSaving
                                      ? 'Completing Setup...'
                                      : 'Complete Setup & Enter Dashboard',
                                  style: const TextStyle(
                                    fontSize: 16,
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
                            const SizedBox(height: 12),
                            const Text(
                              'Fields marked * are required. Both your profile and a new password must be set to continue.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RequiredBadge extends StatelessWidget {
  const _RequiredBadge();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'REQUIRED',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.error,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  const _SectionTitle({required this.icon, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 22, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurface,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

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
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
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
                    const SizedBox(width: 6),
                    const Icon(Icons.access_time,
                        size: 18, color: AppColors.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'to',
            style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: onCloseTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
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
                    const SizedBox(width: 6),
                    const Icon(Icons.access_time,
                        size: 18, color: AppColors.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
