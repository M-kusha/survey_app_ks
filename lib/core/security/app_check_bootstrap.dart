import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

typedef AppCheckActivation = Future<void> Function();

class AppCheckActivationCoordinator {
  AppCheckActivationCoordinator(this._activateProvider);

  final AppCheckActivation _activateProvider;
  Future<void>? _inFlight;
  bool _activated = false;

  bool get isActivated => _activated;

  Future<void> activate() {
    if (_activated) return Future<void>.value();
    final current = _inFlight;
    if (current != null) return current;

    late final Future<void> flight;
    flight = _activate().whenComplete(() {
      if (identical(_inFlight, flight)) _inFlight = null;
    });
    _inFlight = flight;
    return flight;
  }

  Future<void> _activate() async {
    await _activateProvider();
    _activated = true;
  }
}

abstract final class AppCheckBootstrap {
  static const _webSiteKey = String.fromEnvironment(
    'FIREBASE_APP_CHECK_WEB_KEY',
  );
  static const _debugToken = String.fromEnvironment(
    'FIREBASE_APP_CHECK_DEBUG_TOKEN',
  );

  static final AppCheckActivationCoordinator _coordinator =
      AppCheckActivationCoordinator(_activateProvider);

  static Future<void> activate() => _coordinator.activate();

  static Future<void> _activateProvider() async {
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

      providerWindows: WindowsDebugProvider(debugToken: debugToken),
    );
  }
}
