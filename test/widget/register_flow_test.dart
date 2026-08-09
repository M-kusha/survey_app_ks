import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/localization/app_locales.dart';
import 'package:echomeet/core/theme/app_theme.dart';
import 'package:echomeet/core/widgets/glass_panel.dart';
import 'package:echomeet/register/register_1step.dart';
import 'package:echomeet/register/register_3step.dart';
import 'package:echomeet/register/register_logics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/load_fonts.dart';
import '../support/load_translations.dart';

/// Registration screens, driven without Firebase.
///
/// Nothing here signs anyone up — `registerUser` is the last thing each flow
/// calls and it needs a live backend. What these cover is the part that broke
/// repeatedly: whether the screens render at all, whether the continue button
/// is reachable, and whether the step you are on is the step you asked for.
Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  Size size = const Size(393, 852),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData.fromView(
        tester.view,
      ).copyWith(disableAnimations: true),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        locale: AppLocales.fallback,
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

/// The shell's primary action.
FilledButton _continueButton(WidgetTester tester) =>
    tester.widget<FilledButton>(
      find.descendant(
        of: find.byType(GlowButton),
        matching: find.byType(FilledButton),
      ),
    );

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadAppFonts();
    await loadAppTranslations();
  });

  group('step 1', () {
    testWidgets('continue is visible but disabled until a path is chosen', (
      tester,
    ) async {
      await _pump(tester, Register1step(registerLogic: RegisterLogic()));

      // The old screen hid the button entirely, so an undecided user saw a
      // page with no way forward and no explanation.
      expect(find.byType(GlowButton), findsOneWidget);
      expect(_continueButton(tester).onPressed, isNull);

      await tester.tap(find.text('register_as_company'.tr()));
      await tester.pumpAndSettle();

      expect(_continueButton(tester).onPressed, isNotNull);
    });

    testWidgets('the two paths are mutually exclusive', (tester) async {
      await _pump(tester, Register1step(registerLogic: RegisterLogic()));

      await tester.tap(find.text('register_as_company'.tr()));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

      await tester.tap(find.text('register_as_user'.tr()));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('reports its position in the flow', (tester) async {
      await _pump(tester, Register1step(registerLogic: RegisterLogic()));

      expect(
        find.text('step_of'.tr(namedArgs: {'current': '1', 'total': '4'})),
        findsOneWidget,
      );
    });
  });

  group('step 3', () {
    Widget passwordStep(ProfileType type) =>
        Register3step(registerLogic: RegisterLogic(), profileType: type);

    testWidgets('a weak password is refused and says so', (tester) async {
      await _pump(tester, passwordStep(ProfileType.company));

      await tester.enterText(find.byType(TextField).first, 'abc');
      await tester.tap(find.byType(GlowButton));
      await tester.pumpAndSettle();

      expect(find.text('validate_password_strong'.tr()), findsOneWidget);
    });

    testWidgets('a mismatched confirmation is refused', (tester) async {
      await _pump(tester, passwordStep(ProfileType.company));

      await tester.enterText(find.byType(TextField).first, 'Tr0ub4dor&3xyz');
      await tester.enterText(find.byType(TextField).last, 'something-else');
      await tester.tap(find.byType(GlowButton));
      await tester.pumpAndSettle();

      expect(find.text('passwords_dont_match'.tr()), findsOneWidget);
    });

    testWidgets('the meter follows the password as it is typed', (
      tester,
    ) async {
      await _pump(tester, passwordStep(ProfileType.company));

      expect(find.textContaining('password_weak'.tr()), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Tr0ub4dor&3xyz');
      await tester.pumpAndSettle();

      // The bar and the gate read the same estimate, so a password strong
      // enough to be accepted can never still be labelled weak.
      expect(find.textContaining('password_weak'.tr()), findsNothing);
    });

    testWidgets('the last step for a company is labelled as the last', (
      tester,
    ) async {
      await _pump(tester, passwordStep(ProfileType.company));
      expect(find.text('finish_registration'.tr()), findsOneWidget);

      await _pump(tester, passwordStep(ProfileType.user));
      expect(find.text('next'.tr()), findsOneWidget);
    });
  });

  testWidgets('the wide layout splits story from form', (tester) async {
    await _pump(
      tester,
      Register1step(registerLogic: RegisterLogic()),
      size: const Size(1280, 800),
    );

    // Two columns, story left of form, neither overlapping the other. Asserting
    // the geometry is what catches a MediaQuery that reports the wrong width
    // and quietly renders the phone layout on a desktop.
    //
    // Not "headline ends before the midpoint" — the panes are 6:5, so the left
    // one legitimately runs past halfway.
    final panel = tester.getRect(find.byType(GlassPanel));
    final headline = tester.getRect(find.text('register_step1_title'.tr()));

    expect(headline.left, lessThan(panel.left));
    expect(headline.right, lessThanOrEqualTo(panel.left));
  });
}
