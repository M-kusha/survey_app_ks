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

/// Golden images of the auth screens in both themes.
///
///     flutter test --update-goldens test/golden
///
/// Rendered with animations disabled. The aurora background drifts on a real
/// device, and a moving background cannot produce a stable golden — the same
/// MediaQuery flag also switches the effect off for people who have asked their
/// OS for reduced motion, so this exercises that path too.
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

  // Derived from the view, not built from scratch. A bare MediaQueryData here
  // reports Size.zero, so any layout that branches on width silently renders
  // its narrow form at desktop dimensions — which is exactly what a desktop
  // golden is meant to catch.
  final media = MediaQueryData.fromView(
    tester.view,
  ).copyWith(disableAnimations: true);

  await tester.pumpWidget(
    MediaQuery(
      data: media,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        // The language button reads this, so it has to be set for the golden to
        // show the locale actually under test.
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
    // Without this every glyph renders as a filled box and the goldens are
    // useless for judging anything but layout.
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

      // PageBody caps the form at 460 regardless of window width — the fix for
      // a login card that used to span the whole monitor.
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
      // pumpAndSettle returning at all proves it: with the aurora tickers
      // running, the frame scheduler never goes idle and this times out.
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('focusing a field does not resize or move it', (tester) async {
      await _pump(tester, AppTheme.dark, const LoginPage());

      final email = find.byType(TextField).first;
      final before = tester.getRect(email);

      await tester.tap(email);
      await tester.pumpAndSettle();

      // The focus ring is a shadow precisely so this holds. Drawn as a thicker
      // border it would push the text and reflow everything under it.
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

      // By type, not by label: `login_title` and `login_button` both read
      // "Login", so matching on the text finds two widgets.
      await tester.tap(find.byType(GlowButton));
      await tester.pumpAndSettle();

      // Both fields reject empty input, so both messages should be showing.
      expect(find.text('invalid_email_message'.tr()), findsOneWidget);
      expect(find.text('password_empty'.tr()), findsOneWidget);

      // Space for the message is reserved whether or not there is one, so
      // nothing shifts when it arrives. Without that, the password field jumps
      // down the moment the email above it fails.
      expect(tester.getRect(email), emailBefore);
      expect(tester.getRect(password), passwordBefore);
    });
  });

  group('localised', () {
    // Reloads the global translation table, so it has to be undone or every
    // test that runs after this group would see German.
    tearDown(() => loadAppTranslations());

    for (final code in ['de', 'sq']) {
      testWidgets('$code translates the product art too', (tester) async {
        await loadAppTranslations(locale: code);
        // Deliberately leaves MaterialApp on English. The only delegates
        // available here are the Default* ones, which support `en` alone —
        // handing them a locale they cannot resolve makes Localizations
        // reload forever and `pumpAndSettle` sits there until it times out.
        //
        // Copy comes from `.tr()`, which reads the table loaded above, so the
        // assertions below still test the real translated strings.
        await _pump(
          tester,
          AppTheme.dark,
          const LoginPage(),
          size: const Size(1280, 800),
        );

        // The miniatures used to hold English string literals, so they stayed
        // in English while the rest of the screen translated. Asserting the
        // translated copy is present is what stops that coming back.
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

      // The screen used to carry an AppBar, which reserved height at the top
      // and pushed the card above centre on a wide window. This asserts the
      // card's centre against the window's, not merely that it renders.
      final card = tester.getRect(find.byType(Form));
      expect((card.center.dy - 400).abs(), lessThan(24));

      await expectLater(
        find.byType(ResetPasswordPage),
        matchesGoldenFile('goldens/reset_desktop_dark.png'),
      );
    });
  });
}
