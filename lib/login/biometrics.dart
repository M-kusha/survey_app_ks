import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
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
    bool authenticated = false;
    try {
      authenticated = await auth.authenticate(
        localizedReason: 'authenticate_with_biometrics'.tr(),
        authMessages: const <AuthMessages>[AndroidAuthMessages()],
        // local_auth 3.x flattened AuthenticationOptions into named args;
        // stickyAuth is now persistAcrossBackgrounding.
        persistAcrossBackgrounding: true,
      );
    } catch (e) {
      authenticated = false;
    }
    return authenticated;
  }
}
