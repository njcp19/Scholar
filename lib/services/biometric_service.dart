import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// FR-26 / FR-27 — Fingerprint (or face) registration + biometric unlock.
///
/// Device biometric binding, not fingerprint enrollment:
///  1. [deviceSupportsBiometrics] / [enrolledBiometrics] ask the OS what the
///     device can actually do (`canCheckBiometrics`, `getAvailableBiometrics`).
///  2. [register] shows the OS prompt; registration only succeeds when the OS
///     verifies an already-enrolled fingerprint. The result is stored on the
///     device AND on the scholar's profile (`biometric_registered`).
///  3. [verify] re-prompts the OS before releasing an allowance claim.
///
/// Scholar Wallet never sees fingerprint data: matching happens inside the
/// device's secure hardware. Only the Firebase email/password used for the
/// optional biometric LOGIN is stored locally, and only when the scholar
/// explicitly turns biometric login on.
class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();

  /// Email + password for biometric login live in the Android Keystore-backed
  /// secure storage, NOT in plain SharedPreferences.
  static const FlutterSecureStorage _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _kEnabled = 'bio_enabled';
  static const _kEmail = 'bio_email';
  static const _kPassword = 'bio_password';
  static const _kUid = 'bio_registered_uid';
  static const _kEnrolledAt = 'bio_enrolled_at';

  // ------------------------------------------------------------ capability

  Future<bool> deviceSupportsBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final supported = await _localAuth.isDeviceSupported();
      return canCheck || supported;
    } catch (_) {
      return false;
    }
  }

  /// Fingerprints / faces already enrolled in the OS. Empty means the scholar
  /// must add one in the phone settings before the app can register it.
  Future<List<BiometricType>> enrolledBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (_) {
      return <BiometricType>[];
    }
  }

  static String labelFor(BiometricType t) {
    switch (t) {
      case BiometricType.face:
        return 'Face';
      case BiometricType.fingerprint:
        return 'Fingerprint';
      case BiometricType.iris:
        return 'Iris';
      case BiometricType.strong:
        return 'Device biometric';
      case BiometricType.weak:
        return 'Device biometric (weak)';
    }
  }

  // ------------------------------------------------------------- challenge

  /// Shows the OS prompt. True only when the OS verified the biometric.
  Future<bool> verify({String reason = 'Verify your identity'}) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  // ------------------------------------------------------------ enrollment

  Future<bool> isRegisteredFor(String uid) async {
    final p = await SharedPreferences.getInstance();
    return (p.getString(_kUid) == uid) && (p.getString(_kEnrolledAt) != null);
  }

  Future<DateTime?> enrolledAt() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kEnrolledAt);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  /// Registers this device's fingerprint for [uid].
  /// Returns false when the OS prompt failed or nothing is enrolled.
  Future<bool> register(String uid) async {
    if (!await deviceSupportsBiometrics()) return false;
    final available = await enrolledBiometrics();
    final hasSensor =
        available.isNotEmpty || await _localAuth.canCheckBiometrics;
    if (!hasSensor) return false;

    final ok = await verify(
      reason: 'Enable device biometrics for Scholar Wallet',
    );
    if (!ok) return false;

    final now = DateTime.now();
    final p = await SharedPreferences.getInstance();
    await p.setString(_kUid, uid);
    await p.setString(_kEnrolledAt, now.toIso8601String());

    // Mirror the status to the profile so the admin dashboard can show it.
    try {
      await Supabase.instance.client.from('profiles').update({
        'biometric_registered': true,
        'biometric_enrolled_at': now.toUtc().toIso8601String(),
      }).eq('id', uid);
    } catch (_) {
      // Offline is fine — local enrollment already succeeded.
    }
    return true;
  }

  /// Removes the fingerprint registration AND the saved login credentials.
  Future<void> unregister(String uid) async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kUid);
    await p.remove(_kEnrolledAt);
    await _clearCredentials(p);
    try {
      await Supabase.instance.client.from('profiles').update({
        'biometric_registered': false,
        'biometric_enrolled_at': null,
      }).eq('id', uid);
    } catch (_) {}
  }

  // --------------------------------------------------------- biometric login

  Future<bool> isEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kEnabled) ?? false;
  }

  /// Enables fingerprint LOGIN with the given credentials (stored on-device).
  Future<void> enable(String email, String password) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kEnabled, true);
    await _secure.write(key: _kEmail, value: email.trim());
    await _secure.write(key: _kPassword, value: password);
    // Make sure no old plain-text copy is left behind.
    await p.remove(_kEmail);
    await p.remove(_kPassword);
  }

  Future<void> disable() async {
    final p = await SharedPreferences.getInstance();
    await _clearCredentials(p);
  }

  Future<void> _clearCredentials(SharedPreferences p) async {
    await p.setBool(_kEnabled, false);
    await p.remove(_kEmail); // legacy plain-text copies
    await p.remove(_kPassword);
    try {
      await _secure.delete(key: _kEmail);
      await _secure.delete(key: _kPassword);
    } catch (_) {}
  }

  Future<(String email, String password)?> savedCredentials() async {
    final p = await SharedPreferences.getInstance();
    if (!(p.getBool(_kEnabled) ?? false)) return null;
    String? email;
    String? password;
    try {
      email = await _secure.read(key: _kEmail);
      password = await _secure.read(key: _kPassword);
    } catch (_) {}

    // One-time migration from the old plain-text SharedPreferences storage.
    if (email == null || password == null) {
      final oldEmail = p.getString(_kEmail);
      final oldPassword = p.getString(_kPassword);
      if (oldEmail != null && oldPassword != null) {
        try {
          await _secure.write(key: _kEmail, value: oldEmail);
          await _secure.write(key: _kPassword, value: oldPassword);
          await p.remove(_kEmail);
          await p.remove(_kPassword);
        } catch (_) {}
        email = oldEmail;
        password = oldPassword;
      }
    }
    if (email == null || password == null) return null;
    return (email, password);
  }
}
