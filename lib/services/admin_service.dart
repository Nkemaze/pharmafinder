import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../config/admin_config.dart';
import '../firebase_options.dart';

/// Server-side style helpers used by the administrator dashboard.
///
/// Creating pharmacy accounts is done through the Firebase Identity Toolkit
/// REST API (instead of `createUserWithEmailAndPassword`) so that the
/// administrator stays signed in when provisioning new pharmacies.
class AdminService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference get _pharmacies => _db.collection('pharmacies');
  CollectionReference get _admins => _db.collection('admins');

  /// True when at least one administrator account exists in Firestore.
  Future<bool> hasAnyAdmin() async {
    final snap = await _admins.limit(1).get();
    return snap.docs.isNotEmpty;
  }

  /// Creates the very first administrator account.
  ///
  /// Requires [setupCode] to match [AdminConfig.adminSetupCode]. The new user
  /// is created via the auth SDK (which signs the session in as the admin) and
  /// a matching `admins/{uid}` document is written.
  Future<void> createAdminAccount({
    required String email,
    required String password,
    required String setupCode,
  }) async {
    if (setupCode.trim() != AdminConfig.adminSetupCode) {
      throw const AdminSetupException('The setup code is incorrect.');
    }
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    try {
      await _admins.doc(cred.user!.uid).set({
        'email': email.trim(),
        'role': 'admin',
        'setupKey': AdminConfig.adminSetupCode,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Roll back the created auth account so we do not leave an orphaned
      // administrator that cannot be managed.
      try {
        await cred.user!.delete();
      } catch (_) {}
      rethrow;
    }
  }

  /// Creates a pharmacy authentication account and its Firestore profile.
  ///
  /// Uses the public Identity Toolkit sign-up endpoint so the current admin
  /// session is preserved. Returns the new pharmacy uid. The new pharmacy is
  /// flagged with `mustUpdateProfile: true` so it is forced to set its own
  /// profile and password on first login.
  Future<String> createPharmacyAccount({
    required String name,
    required String email,
    required String password,
  }) async {
    final apiKey = DefaultFirebaseOptions.web.apiKey;
    final uri = Uri.parse(
        'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email.trim(),
        'password': password,
        'returnSecureToken': true,
      }),
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      final raw =
          (body['error']?['message'] as String?) ?? 'Failed to create account';
      throw AdminSetupException(_friendlyAuthMessage(raw));
    }

    final uid = body['localId'] as String;
    await _pharmacies.doc(uid).set({
      'name': name.trim(),
      'email': email.trim(),
      'status': 'active',
      'mustUpdateProfile': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return uid;
  }

  /// Sends a password-reset email to the pharmacy so they can set a new
  /// password themselves (client apps cannot change another user's password).
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Suspends or activates a pharmacy account ('active' | 'suspended').
  Future<void> setPharmacyStatus(String uid, String status) async {
    await _pharmacies.doc(uid).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Soft-deletes a pharmacy (auth account removal requires the Firebase
  /// console, so the login is blocked at the app level instead).
  Future<void> deletePharmacy(String uid) async {
    await _pharmacies.doc(uid).update({
      'status': 'deleted',
      'deletedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Removes the forced-setup flag once the pharmacy has completed onboarding.
  Future<void> markProfileCompleted(String uid) async {
    await _pharmacies.doc(uid).update({
      'mustUpdateProfile': false,
      'profileCompletedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Maps raw Identity Toolkit error strings to friendly messages.
  String _friendlyAuthMessage(String raw) {
    if (raw.contains('EMAIL_EXISTS')) {
      return 'A pharmacy account with this email already exists.';
    }
    if (raw.contains('INVALID_EMAIL')) {
      return 'The email address is not valid.';
    }
    if (raw.contains('WEAK_PASSWORD')) {
      return 'The password must be at least 6 characters.';
    }
    return raw.replaceAll('_', ' ').toLowerCase();
  }
}

/// Thrown for expected, user-displayable admin flow errors.
class AdminSetupException implements Exception {
  final String message;
  const AdminSetupException(this.message);

  @override
  String toString() => message;
}
