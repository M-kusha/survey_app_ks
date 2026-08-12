import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/localization/app_locales.dart';
import 'package:echomeet/core/theme/app_theme.dart';
import 'package:echomeet/core/widgets/glass_panel.dart';
import 'package:echomeet/login/login.dart';
import 'package:echomeet/login/user_preferences.dart';
import 'package:echomeet/reset_password/reset_password.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/load_fonts.dart';
import '../support/load_translations.dart';

Future<void> _pump(
  WidgetTester tester,
  ThemeData theme,
  Widget screen, {
  Size size = const Size(393, 852),
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final media = MediaQueryData.fromView(
    tester.view,
  ).copyWith(disableAnimations: true);

  await tester.pumpWidget(
    MediaQuery(
      data: media,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,

        locale: locale,
        supportedLocales: AppLocales.supported,
        localizationsDelegates: const [
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        home: screen,
      ),
    ),
  );

  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await UserPreferences.init();

    await loadAppFonts();
    await loadAppTranslations();
  });

  group('login', () {
    testWidgets('light', (tester) async {
      await _pump(tester, AppTheme.light, const LoginPage());
      await expectLater(
        find.byType(LoginPage),
        matchesGoldenFile('goldens/login_mobile_light.png'),
      );
    });

    testWidgets('dark', (tester) async {
      await _pump(tester, AppTheme.dark, const LoginPage());
      await expectLater(
        find.byType(LoginPage),
        matchesGoldenFile('goldens/login_mobile_dark.png'),
      );
    });

    testWidgets('desktop keeps the card at a readable width', (tester) async {
      await _pump(
        tester,
        AppTheme.dark,
        const LoginPage(),
        size: const Size(1280, 800),
      );

      final card = tester.getSize(find.byType(Form));
      expect(card.width, lessThanOrEqualTo(460));

      await expectLater(
        find.byType(LoginPage),
        matchesGoldenFile('goldens/login_desktop_dark.png'),
      );
    });

    testWidgets('the password starts obscured', (tester) async {
      await _pump(tester, AppTheme.light, const LoginPage());
      final fields = tester
          .widgetList<EditableText>(find.byType(EditableText))
          .toList();
      expect(fields.length, 2, reason: 'email and password');
      expect(fields[1].obscureText, isTrue);
    });

    testWidgets('reduced motion stops the background animating', (
      tester,
    ) async {
      await _pump(tester, AppTheme.dark, const LoginPage());

      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('focusing a field does not resize or move it', (tester) async {
      await _pump(tester, AppTheme.dark, const LoginPage());

      final email = find.byType(TextField).first;
      final before = tester.getRect(email);

      await tester.tap(email);
      await tester.pumpAndSettle();

      expect(tester.getRect(email), before);

      await expectLater(
        find.byType(LoginPage),
        matchesGoldenFile('goldens/login_mobile_dark_focused.png'),
      );
    });

    testWidgets('a validation error appears without moving the fields', (
      tester,
    ) async {
      await _pump(tester, AppTheme.light, const LoginPage());

      final email = find.byType(TextField).first;
      final password = find.byType(TextField).last;
      final emailBefore = tester.getRect(email);
      final passwordBefore = tester.getRect(password);

      await tester.tap(find.byType(GlowButton));
      await tester.pumpAndSettle();

      expect(find.text('invalid_email_message'.tr()), findsOneWidget);
      expect(find.text('password_empty'.tr()), findsOneWidget);

      expect(tester.getRect(email), emailBefore);
      expect(tester.getRect(password), passwordBefore);
    });
  });

  group('localised', () {
    tearDown(() => loadAppTranslations());

    for (final code in ['de', 'sq']) {
      testWidgets('$code translates the product art too', skip: true, (
        tester,
      ) async {
        await loadAppTranslations(locale: code);

        await _pump(
          tester,
          AppTheme.dark,
          const LoginPage(),
          size: const Size(1280, 800),
        );

        expect(find.text('showcase_meeting_label'.tr()), findsOneWidget);
        expect(find.text('showcase_attending_label'.tr()), findsOneWidget);
        expect(find.text('login_headline'.tr()), findsOneWidget);
      });
    }
  });

  group('reset password', () {
    testWidgets('light', (tester) async {
      await _pump(tester, AppTheme.light, const ResetPasswordPage());
      await expectLater(
        find.byType(ResetPasswordPage),
        matchesGoldenFile('goldens/reset_mobile_light.png'),
      );
    });

    testWidgets('dark', (tester) async {
      await _pump(tester, AppTheme.dark, const ResetPasswordPage());
      await expectLater(
        find.byType(ResetPasswordPage),
        matchesGoldenFile('goldens/reset_mobile_dark.png'),
      );
    });

    testWidgets('desktop centres the card vertically', (tester) async {
      await _pump(
        tester,
        AppTheme.dark,
        const ResetPasswordPage(),
        size: const Size(1280, 800),
      );

      final card = tester.getRect(find.byType(Form));
      expect((card.center.dy - 400).abs(), lessThan(24));

      await expectLater(
        find.byType(ResetPasswordPage),
        matchesGoldenFile('goldens/reset_desktop_dark.png'),
      );
    });
  });
}
