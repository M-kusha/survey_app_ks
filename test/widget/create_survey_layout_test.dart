import 'package:echomeet/settings/font_size_provider.dart';
import 'package:echomeet/survey_pages/create_survey/step3_create_survey.dart';
import 'package:echomeet/survey_pages/utilities/survey_questionary_class.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Layout guards for the survey builder.
///
/// This screen has now been broken twice by changes to where the finish button
/// lives, and both times the failure was invisible to `flutter analyze`:
///
///   1. the button sat on the last page of the PageView, so it disappeared the
///      moment you added a question and were carried onto that question's card
///   2. moving it into `bottomNavigationBar` handed a bare `Center` loose
///      constraints, and `Center` expands to fill them — the bar grew to the
///      full screen height and squeezed the page to nothing
///
/// The assertions below are deliberately about *geometry* rather than about
/// which widgets exist. Both bugs left a perfectly valid widget tree.

Survey _survey() => Survey(
  surveyName: 'Test',
  surveyDescription: 'Test survey',
  timeCreated: DateTime(2026, 1, 1),
  questions: const [],
  id: 'survey-1',
  deadline: DateTime(2026, 12, 31),
  participants: const [],
  companyId: 'company-1',
);

Future<void> _pump(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ChangeNotifierProvider<FontSizeProvider>(
      create: (_) => FontSizeProvider(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: CreateTrainingSurveyStep3(survey: _survey()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('survey builder layout', () {
    testWidgets('the page keeps most of the screen, not the bottom bar', (
      tester,
    ) async {
      const screen = Size(390, 844);
      await _pump(tester, screen);

      final pageView = tester.getSize(find.byType(PageView));

      // The exact split does not matter; what matters is that the pager is
      // still the dominant element. When the bottom bar expanded it took the
      // entire height and this was 0.
      expect(
        pageView.height,
        greaterThan(screen.height * 0.5),
        reason: 'the bottom bar has swallowed the page',
      );
    });

    testWidgets('the finish button is a bar, not a full-height panel', (
      tester,
    ) async {
      const screen = Size(390, 844);
      await _pump(tester, screen);

      final button = tester.getSize(find.byType(ElevatedButton).first);
      expect(
        button.height,
        lessThan(screen.height * 0.25),
        reason: 'the finish button is filling the screen',
      );
    });

    testWidgets('the finish button is reachable with no questions yet', (
      tester,
    ) async {
      await _pump(tester, const Size(390, 844));
      // Regression one: it used to live on the last page of the pager, so it
      // was only reachable by swiping there.
      expect(find.byType(ElevatedButton), findsWidgets);
    });

    testWidgets('nothing overflows on a short window', (tester) async {
      // Landscape phone is the tightest realistic case, and the page starts
      // with a fixed 200px spacer.
      await _pump(tester, const Size(844, 390));
      expect(tester.takeException(), isNull);
    });
  });
}
