import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

abstract final class AppCheckBootstrap {
  static const _webSiteKey = String.fromEnvironment(
    'FIREBASE_APP_CHECK_WEB_KEY',
  );
  static const _debugToken = String.fromEnvironment(
    'FIREBASE_APP_CHECK_DEBUG_TOKEN',
  );

  static Future<void> activate() async {
    final debugToken = _debugToken.isEmpty ? null : _debugToken;

    if (!kDebugMode &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.windows) {
      throw UnsupportedError(
        'Windows release is disabled until a production App Check provider is available.',
      );
    }

    WebProvider? webProvider;
    if (kIsWeb) {
      if (kDebugMode) {
        // With no supplied token the Firebase web SDK generates one and prints
        // it once. Register that value in the Firebase console before testing.
        webProvider = WebDebugProvider(debugToken: debugToken);
      } else {
        if (_webSiteKey.isEmpty) {
          throw StateError(
            'Release web builds require FIREBASE_APP_CHECK_WEB_KEY.',
          );
        }
        webProvider = ReCaptchaV3Provider(_webSiteKey);
      }
    }

    await FirebaseAppCheck.instance.activate(
      providerWeb: webProvider,
      providerAndroid: kDebugMode
          ? AndroidDebugProvider(debugToken: debugToken)
          : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? AppleDebugProvider(debugToken: debugToken)
          : const AppleAppAttestWithDeviceCheckFallbackProvider(),
      // FlutterFire requires a Windows provider argument and currently offers
      // only debug. The release guard above makes this value unreachable in a
      // Windows release; other platforms ignore it.
      providerWindows: WindowsDebugProvider(debugToken: debugToken),
    );
  }
}
