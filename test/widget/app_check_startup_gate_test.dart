import 'dart:async';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/localization/app_locales.dart';
import 'package:echomeet/core/security/app_check_startup_gate.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const protectedApp = Directionality(
  textDirection: ui.TextDirection.ltr,
  child: Text('protected app', key: Key('protected-app')),
);

class _TestAssetLoader extends AssetLoader {
  const _TestAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => {
    'app_check_starting': 'Checking securely',
    'app_check_configuration_title': 'Cannot start',
    'app_check_configuration_body': 'Configuration missing',
    'app_check_unavailable_title': 'Check unavailable',
    'app_check_unavailable_body': 'Try again',
    'retry': 'Retry',
  };
}

Future<void> settleGate(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Widget host(Widget child) => EasyLocalization(
    key: UniqueKey(),
    supportedLocales: AppLocales.supported,
    path: AppLocales.path,
    fallbackLocale: AppLocales.fallback,
    saveLocale: false,
    assetLoader: const _TestAssetLoader(),
    child: child,
  );

  testWidgets('transient activation retries before exposing the app', (
    tester,
  ) async {
    var calls = 0;
    var announcements = 0;
    await tester.pumpWidget(
      host(
        AppCheckStartupGate(
          key: UniqueKey(),
          retryDelay: Duration.zero,
          activate: () async {
            calls += 1;
            if (calls == 1) {
              throw FirebaseException(plugin: 'app-check', code: 'unavailable');
            }
          },
          onActivated: () => announcements += 1,
          child: protectedApp,
        ),
      ),
    );
    expect(find.byKey(const Key('protected-app')), findsNothing);

    await settleGate(tester);

    expect(calls, 2);
    expect(announcements, 1);
    expect(find.byKey(const Key('protected-app')), findsOneWidget);
  });

  testWidgets('several automatic transient failures still recover', (
    tester,
  ) async {
    var calls = 0;
    var announcements = 0;
    await tester.pumpWidget(
      host(
        AppCheckStartupGate(
          key: UniqueKey(),
          retryDelay: Duration.zero,
          activate: () async {
            calls += 1;
            if (calls < 3) {
              throw FirebaseException(
                plugin: 'app-check',
                code: 'network-request-failed',
              );
            }
          },
          onActivated: () => announcements += 1,
          child: protectedApp,
        ),
      ),
    );
    expect(find.byKey(const Key('protected-app')), findsNothing);

    await settleGate(tester);

    expect(calls, 3);
    expect(announcements, 1);
    expect(find.byKey(const Key('protected-app')), findsOneWidget);
    expect(find.byKey(const Key('app-check-retry')), findsNothing);
  });

  testWidgets('configuration errors remain closed and are not retried', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      host(
        AppCheckStartupGate(
          key: UniqueKey(),
          retryDelay: Duration.zero,
          activate: () async {
            calls += 1;
            throw StateError('missing release web key');
          },
          child: protectedApp,
        ),
      ),
    );
    await settleGate(tester);

    expect(calls, 1);
    expect(find.byKey(const Key('app-check-failure-configuration')), findsOne);
    expect(find.byKey(const Key('app-check-retry')), findsNothing);
    expect(find.byKey(const Key('protected-app')), findsNothing);
  });

  testWidgets('manual retry starts one new cycle after bounded exhaustion', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      host(
        AppCheckStartupGate(
          key: UniqueKey(),
          retryDelay: Duration.zero,
          activate: () async {
            calls += 1;
            if (calls <= 3) throw TimeoutException('offline');
          },
          child: protectedApp,
        ),
      ),
    );
    await settleGate(tester);
    expect(calls, 3);

    await tester.tap(find.byKey(const Key('app-check-retry')));
    await settleGate(tester);

    expect(calls, 4);
    expect(find.byKey(const Key('protected-app')), findsOneWidget);
  });

  testWidgets('repeated retry taps share one in-flight activation', (
    tester,
  ) async {
    final retry = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      host(
        AppCheckStartupGate(
          key: UniqueKey(),
          maxAttempts: 1,
          activate: () {
            calls += 1;
            if (calls == 1) throw TimeoutException('offline');
            return retry.future;
          },
          child: protectedApp,
        ),
      ),
    );
    await settleGate(tester);

    final button = find.byKey(const Key('app-check-retry'));
    await tester.tap(button);
    await tester.tap(button);
    await tester.pump();
    expect(calls, 2);

    retry.complete();
    await settleGate(tester);
    expect(find.byKey(const Key('protected-app')), findsOneWidget);
  });

  testWidgets('dispose cancels a pending backoff without activating later', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      host(
        AppCheckStartupGate(
          key: UniqueKey(),
          retryDelay: const Duration(seconds: 10),
          activate: () async {
            calls += 1;
            throw TimeoutException('offline');
          },
          child: protectedApp,
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 20));

    expect(calls, 1);
  });

  testWidgets('resume retries a retryable exhausted gate', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      host(
        AppCheckStartupGate(
          key: UniqueKey(),
          maxAttempts: 1,
          activate: () async {
            calls += 1;
            if (calls == 1) throw TimeoutException('offline');
          },
          child: protectedApp,
        ),
      ),
    );
    await settleGate(tester);
    expect(calls, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settleGate(tester);

    expect(calls, 2);
    expect(find.byKey(const Key('protected-app')), findsOneWidget);
  });

  test('classifies errors without retaining their raw contents', () {
    expect(
      classifyAppCheckStartupError(StateError('secret')),
      AppCheckStartupFailure.configuration,
    );
    expect(
      classifyAppCheckStartupError(
        FirebaseException(plugin: 'app-check', code: 'network-request-failed'),
      ),
      AppCheckStartupFailure.offline,
    );
    expect(
      classifyAppCheckStartupError(Exception('provider')),
      AppCheckStartupFailure.provider,
    );
  });
}
