import 'package:shared_preferences/shared_preferences.dart';

/// Small, non-sensitive preferences that survive a restart.
///
/// Deliberately stores no credentials. An earlier version kept the user's
/// password here in plain text so the login form could pre-fill it, but
/// `SharedPreferences` is an unencrypted file in app storage — readable on a
/// rooted device and swept into Android's auto-backup. Firebase Auth already
/// persists the session, so the password is never needed after sign-in.
class UserPreferences {
  UserPreferences._();

  static const _keyEmail = 'email';
  static const _keyFullName = 'fullName';
  static const _keyRememberMe = 'rememberMe';
  static const _keyBiometricAuth = 'biometricAuth';

  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static Future<void> setUserEmail(String email) =>
      _prefs.setString(_keyEmail, email);
  static String? getEmail() => _prefs.getString(_keyEmail);

  static Future<void> setFullName(String fullName) =>
      _prefs.setString(_keyFullName, fullName);
  static String? getFullName() => _prefs.getString(_keyFullName);

  static Future<void> setRememberMe(bool rememberMe) =>
      _prefs.setBool(_keyRememberMe, rememberMe);
  static bool getRememberMe() => _prefs.getBool(_keyRememberMe) ?? false;

  /// Whether the user opted into unlocking with biometrics on this device.
  ///
  /// This is a device preference rather than part of the session, so it
  /// survives [clearSession].
  static Future<void> setBiometricAuthEnabled(bool isEnabled) =>
      _prefs.setBool(_keyBiometricAuth, isEnabled);
  static bool getBiometricAuthEnabled() =>
      _prefs.getBool(_keyBiometricAuth) ?? false;

  /// Forgets who was signed in. Called on sign-out and account deletion.
  static Future<void> clearSession() async {
    await Future.wait([
      _prefs.remove(_keyEmail),
      _prefs.remove(_keyFullName),
      _prefs.remove(_keyRememberMe),
    ]);
  }
}
