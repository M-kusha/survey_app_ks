import 'package:echomeet/core/localization/app_locales.dart';
import 'package:echomeet/core/theme/app_theme.dart';
import 'package:echomeet/core/widgets/wizard_scaffold.dart';
import 'package:echomeet/survey_pages/create_survey/question_editor.dart';
import 'package:echomeet/survey_pages/create_survey/step3_create_survey.dart';
import 'package:echomeet/survey_pages/utilities/survey_questionary_class.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/load_translations.dart';

/// Layout guards for the survey builder.
///
/// This screen has now been broken three times by where the finish button
/// lives, and none of it was visible to `flutter analyze`:
///
///   1. the button sat on the last page of a PageView, so it disappeared the
///      moment you added a question and were carried onto that question's card
///   2. moving it into `bottomNavigationBar` handed a bare `Center` loose
///      constraints, and `Center` expands to fill them — the bar grew to the
///      full screen height and squeezed the page to nothing
///   3. the same `Center` mistake again, in the shared action bar
///
/// The builder is a scrolling list now rather than a swipe deck, so these
/// assert the properties that survived the redesign: the button exists before
/// you have written anything, the bar is a bar, and adding a question adds an
/// editor without navigating anywhere.
Survey _survey({SurveyType type = SurveyType.survey}) => Survey(
  surveyName: 'Test',
  surveyDescription: 'Test survey',
  timeCreated: DateTime(2026, 1, 1),
  questions: const [],
  id: 'survey-1',
  deadline: DateTime(2026, 12, 31),
  participants: const [],
  surveyType: type,
  companyId: 'company-1',
);

Future<void> _pump(
  WidgetTester tester,
  Size size, {
  SurveyType type = SurveyType.survey,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      supportedLocales: AppLocales.supported,
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      home: CreateTrainingSurveyStep3(survey: _survey(type: type)),
    ),
  );
  await tester.pumpAndSettle();
}

/// The three "add a question" buttons at the foot of the list.
Finder get _addButtons => find.byType(OutlinedButton);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await loadAppTranslations();
  });

  group('layout', () {
    testWidgets('the action bar is a bar, not a full-height panel', (
      tester,
    ) async {
      const screen = Size(390, 844);
      await _pump(tester, screen);

      final bar = tester.getSize(find.byType(WizardActionBar));
      expect(
        bar.height,
        lessThan(screen.height / 4),
        reason: 'the bar swallowed the page twice before',
      );
    });

    testWidgets('the finish button is there before any questions exist', (
      tester,
    ) async {
      await _pump(tester, const Size(390, 844));
      expect(find.byType(FilledButton), findsWidgets);
    });

    testWidgets('nothing overflows on a short window', (tester) async {
      await _pump(tester, const Size(844, 390));
      expect(tester.takeException(), isNull);
    });

    testWidgets('nothing overflows on a narrow one either', (tester) async {
      // 320 is the narrowest phone still in use, and the three add-buttons sit
      // in a row with translated labels.
      await _pump(tester, const Size(320, 700));
      expect(tester.takeException(), isNull);
    });
  });

  group('adding questions', () {
    testWidgets('a question can be added without navigating anywhere', (
      tester,
    ) async {
      await _pump(tester, const Size(390, 844));
      expect(find.byType(QuestionEditor), findsNothing);

      await tester.tap(_addButtons.first);
      await tester.pumpAndSettle();

      expect(find.byType(QuestionEditor), findsOneWidget);
    });

    testWidgets('several are visible at once', (tester) async {
      // The whole point of dropping the PageView: you can see the survey.
      await _pump(tester, const Size(390, 844));

      for (var i = 0; i < 3; i++) {
        // The add buttons sit below the questions, so they move down the page
        // as it fills — which is the point of a list, and means the test has to
        // scroll to them the way a person would.
        await tester.ensureVisible(_addButtons.first);
        await tester.pumpAndSettle();
        await tester.tap(_addButtons.first);
        await tester.pumpAndSettle();
      }

      expect(find.byType(QuestionEditor), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a choice question starts with two blank options', (
      tester,
    ) async {
      // Starting with none made the card look finished when it was not, and
      // the old editor happily saved a choice with nothing to choose between.
      await _pump(tester, const Size(390, 844));

      await tester.tap(_addButtons.first);
      await tester.pumpAndSettle();

      // One field for the question, two for the options.
      expect(find.byType(TextFormField), findsNWidgets(3));
    });

    testWidgets('a text question has no options', (tester) async {
      await _pump(tester, const Size(390, 844));

      await tester.tap(_addButtons.last);
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('removing a question removes its editor', (tester) async {
      await _pump(tester, const Size(390, 844));

      await tester.tap(_addButtons.first);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(QuestionEditor), findsNothing);
    });
  });
}
