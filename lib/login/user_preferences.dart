import 'package:shared_preferences/shared_preferences.dart';

class UserPreferences {
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static Future<void> setUserEmail(String email) async =>
      await _prefs.setString('email', email);
  static String? getUserEmail() => _prefs.getString('email');

  static Future<void> setUserPassword(String password) async =>
      await _prefs.setString('password', password);
  static String? getUserPassword() => _prefs.getString('password');

  static Future<void> setFullName(String fullName) async =>
      await _prefs.setString('fullName', fullName);

  static Future<void> setRememberMe(bool rememberMe) async =>
      await _prefs.setBool('rememberMe', rememberMe);
  static bool getRememberMe() => _prefs.getBool('rememberMe') ?? false;

  static Future setBiometricAuthEnabled(bool isEnabled) async =>
      await _prefs.setBool('biometricAuth', isEnabled);

  static String? getEmail() => _prefs.getString('email');
  static String? getPassword() => _prefs.getString('password');
  static String? getFullName() => _prefs.getString('fullName');
  static bool? getBiometricAuthEnabled() => _prefs.getBool('biometricAuth');
}
