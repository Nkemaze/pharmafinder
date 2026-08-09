import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import '../../theme/app_theme.dart';

/// Administrator sign-in portal.
///
/// On the very first run (no admin exists yet) it shows a bootstrap form to
/// create the first administrator account, guarded by [AdminConfig.adminSetupCode].
class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _service = AdminService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _setupCodeController = TextEditingController();

  bool _obscurePassword = true;
  bool _showBootstrap = false;
  bool _checking = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkBootstrap();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _setupCodeController.dispose();
    super.dispose();
  }

  Future<void> _checkBootstrap() async {
    try {
      final hasAdmin = await _service.hasAnyAdmin();
      if (mounted) {
        setState(() {
          _showBootstrap = !hasAdmin;
          _checking = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _checking = false);
    }
  }

  /// Returns to the main app. Reached via the secret named route, the admin
  /// portal has nothing below it in the stack, so we reset the stack to "/".
  void _goHome() {
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Enter your email and password.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final auth = FirebaseAuth.instance;
      await auth.setPersistence(Persistence.LOCAL);
      await auth.signInWithEmailAndPassword(email: email, password: password);
      // Routing is handled by AuthGate via the auth-state stream.
      if (mounted) _goHome();
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = _friendly(e.code, e.message));
    } catch (_) {
      setState(() => _errorMessage = 'An unexpected error occurred.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createAdmin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;
    final code = _setupCodeController.text.trim();

    if (!email.contains('@')) {
      setState(() => _errorMessage = 'Enter a valid email address.');
      return;
    }
    if (password.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters.');
      return;
    }
    if (password != confirm) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await _service.createAdminAccount(
        email: email,
        password: password,
        setupCode: code,
      );
      if (mounted) _goHome();
    } on AdminSetupException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Failed to create administrator: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendly(String? code, String? message) {
    if (code == 'invalid-credential' ||
        code == 'invalid-login-credentials' ||
        code == 'wrong-password' ||
        code == 'user-not-found') {
      return 'Invalid email or password.';
    }
    if (code == 'user-disabled') return 'This account has been disabled.';
    if (code == 'too-many-requests') {
      return 'Too many attempts. Please try again later.';
    }
    return message ?? 'Login failed.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 440,
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.admin_panel_settings_outlined,
                      color: Colors.white, size: 36),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Administrator Portal',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _showBootstrap
                      ? 'No administrator exists yet. Create the first one to get started.'
                      : 'Restricted access for platform administrators.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
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
                  const SizedBox(height: 16),
                ],
                _label('EMAIL ADDRESS'),
                const SizedBox(height: 6),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'admin@pharmafinder.com',
                    prefixIcon: Icon(Icons.mail_outlined, size: 20),
                  ),
                  onChanged: (_) => setState(() => _errorMessage = null),
                ),
                const SizedBox(height: 16),
                _label('PASSWORD'),
                const SizedBox(height: 6),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: '********',
                    prefixIcon: const Icon(Icons.lock_outlined, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                        color: AppColors.outline,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  onChanged: (_) => setState(() => _errorMessage = null),
                ),
                if (_showBootstrap) ...[
                  const SizedBox(height: 16),
                  _label('CONFIRM PASSWORD'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _confirmController,
                    obscureText: _obscurePassword,
                    decoration: const InputDecoration(
                      hintText: '********',
                      prefixIcon: Icon(Icons.lock_outline, size: 20),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _label('SETUP CODE'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _setupCodeController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      hintText: 'Enter the administrator setup code',
                      prefixIcon: Icon(Icons.key_outlined, size: 20),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: (_isLoading || _checking) ? null : (_showBootstrap ? _createAdmin : _login),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(_showBootstrap ? 'Create Administrator Account' : 'Secure Admin Login'),
                  ),
                ),
                const SizedBox(height: 20),
                TextButton.icon(
                  onPressed: _goHome,
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Back to Pharmacy Login'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: AppColors.onSurfaceVariant,
        ),
      ),
    );
  }
}
