import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:survey_app_ks/login/user_preferences.dart';
import 'package:local_auth_android/local_auth_android.dart';

class AuthService {
  final LocalAuthentication auth = LocalAuthentication();

  Future<bool> canCheckBiometrics() async {
    try {
      return await auth.canCheckBiometrics;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> isDeviceSupported() async {
    try {
      return await auth.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  Future<bool> authenticateUser() async {
    final LocalAuthentication auth = LocalAuthentication();
    try {
      return await auth.authenticate(
          localizedReason: 'Please authenticate to access this feature',
          authMessages: const <AuthMessages>[
            AndroidAuthMessages(),
          ]);
    } on PlatformException {
      return false;
    }
  }

  Future<void> attemptBiometricLogin() async {
    final canUseBiometric =
        await canCheckBiometrics() && await isDeviceSupported();
    final biometricEnabled = UserPreferences.getBiometricAuthEnabled() ?? false;

    if (canUseBiometric && biometricEnabled) {
      bool authenticated = await authenticateUser();
      if (!authenticated) {}
    } else {}
  }
}
