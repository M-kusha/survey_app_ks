import 'package:shared_preferences/shared_preferences.dart';

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

  static Future<void> setBiometricAuthEnabled(bool isEnabled) =>
      _prefs.setBool(_keyBiometricAuth, isEnabled);
  static bool getBiometricAuthEnabled() =>
      _prefs.getBool(_keyBiometricAuth) ?? false;

  static Future<void> clearSession() async {
    await Future.wait([
      _prefs.remove(_keyEmail),
      _prefs.remove(_keyFullName),
      _prefs.remove(_keyRememberMe),
    ]);
  }

  static Future<void> endSession() async {
    if (getRememberMe()) return;
    await clearSession();
  }
}
