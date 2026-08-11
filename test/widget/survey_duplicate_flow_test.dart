import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/survey_pages/create_survey/step1_create_survey.dart';
import 'package:echomeet/survey_pages/create_survey/step3_create_survey.dart';
import 'package:echomeet/survey_pages/utilities/survey_questionary_class.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The real English copy, read once off the test clock.
///
/// The bundled loader does file IO, which a fake clock cannot be pumped past:
/// the widget settles while EasyLocalization is still rendering nothing, so the
/// first test in a file passes and every later one finds an empty tree.
class _SyncAssetLoader extends AssetLoader {
  const _SyncAssetLoader();

  static final _english =
      jsonDecode(File('assets/translations/en.json').readAsStringSync())
          as Map<String, dynamic>;

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      _english;
}

Survey _template() => Survey(
  surveyName: 'Security basics (copy)',
  surveyDescription: 'What everyone should know',
  timeCreated: DateTime(2026, 8, 12),
  questions: [
    {
      'type': 'Single',
      'question': 'Which password is strongest?',
      'options': ['abc', 'correct horse battery staple'],
      'correctAnswer': 1,
    },
    {'type': 'Text', 'question': 'Describe a phishing sign'},
  ],
  id: 'new-id',
  deadline: DateTime(2026, 12, 1),
  participants: const [],
  timeLimitPerQuestion: 45,
  surveyType: SurveyType.test,
  companyId: '',
);

Future<void> _pump(WidgetTester tester, Widget home) async {
  await tester.pumpWidget(
    EasyLocalization(
      key: UniqueKey(),
      supportedLocales: const [Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      startLocale: const Locale('en'),
      saveLocale: false,
      assetLoader: const _SyncAssetLoader(),
      child: Builder(
        builder: (context) => MaterialApp(
          localizationsDelegates: [
            ...context.localizationDelegates,
            DefaultMaterialLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
          ],
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: home,
        ),
      ),
    ),
  );
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

  // Tall enough that nothing under test is scrolled out of reach.
  setUp(() {
    final view = TestWidgetsFlutterBinding
        .instance
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(1000, 2400);
    view.devicePixelRatio = 1.0;
  });

  tearDownAll(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.reset();
  });

  testWidgets('duplicating opens the wizard with the name and description', (
    tester,
  ) async {
    await _pump(tester, Step1CreateSurvey(template: _template()));

    expect(find.text('Security basics (copy)'), findsOneWidget);
    expect(find.text('What everyone should know'), findsOneWidget);
  });

  testWidgets('a new survey still starts empty', (tester) async {
    await _pump(tester, const Step1CreateSurvey());

    expect(find.text('Security basics (copy)'), findsNothing);
    expect(find.text('What everyone should know'), findsNothing);
    expect(find.byType(TextFormField), findsWidgets);
  });

  testWidgets('the copied questions reach the step that publishes them', (
    tester,
  ) async {
    // Getting this wrong means a duplicate publishes with no questions at all,
    // which the wizard would happily let you do.
    await _pump(tester, CreateTrainingSurveyStep3(survey: _template()));

    expect(find.text('Which password is strongest?'), findsOneWidget);
    expect(find.text('Describe a phishing sign'), findsOneWidget);
    expect(find.text('correct horse battery staple'), findsOneWidget);
  });

  testWidgets('the template survives being edited in the wizard', (
    tester,
  ) async {
    // Step 1 hands the next step a copy of the question list, so the survey
    // still listed on the screen behind does not change as you type.
    final template = _template();

    await _pump(tester, Step1CreateSurvey(template: template));
    await tester.enterText(find.byType(TextFormField).first, 'A new name');
    await tester.pumpAndSettle();

    expect(template.surveyName, 'Security basics (copy)');
    expect(template.questions, hasLength(2));
  });
}
