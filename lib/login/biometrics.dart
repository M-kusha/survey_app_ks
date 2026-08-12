import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';

class AuthService {
  final LocalAuthentication auth = LocalAuthentication();

  /// Biometric unlock is a device feature, and the web has no such plugin.
  ///
  /// Asking anyway threw `MissingPluginException` — which is not a
  /// `PlatformException`, so the old catch did not see it and the failure
  /// surfaced as an unhandled rejection in the console on every visit to the
  /// settings and sign-in screens.
  bool get _available => !kIsWeb;

  Future<bool> canCheckBiometrics() async {
    if (!_available) return false;
    try {
      return await auth.canCheckBiometrics;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      // A platform this build reaches but the plugin does not implement.
      return false;
    }
  }

  Future<bool> isDeviceSupported() async {
    if (!_available) return false;
    try {
      return await auth.isDeviceSupported();
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> authenticateUser() async {
    if (!_available) return false;
    final LocalAuthentication auth = LocalAuthentication();
    bool authenticated = false;
    try {
      authenticated = await auth.authenticate(
        localizedReason: 'authenticate_with_biometrics'.tr(),
        authMessages: const <AuthMessages>[AndroidAuthMessages()],

        persistAcrossBackgrounding: true,
      );
    } catch (e) {
      authenticated = false;
    }
    return authenticated;
  }
}
