import 'package:echomeet/core/localization/app_locales.dart';
import 'package:echomeet/core/theme/app_theme.dart';
import 'package:echomeet/survey_pages/create_survey/question_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/load_fonts.dart';
import '../support/load_translations.dart';

Future<void> _pump(
  WidgetTester tester,
  Map<String, dynamic> question, {
  required bool isTest,
  VoidCallback? onRemove,
}) async {
  tester.view.physicalSize = const Size(520, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      supportedLocales: AppLocales.supported,
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      home: Scaffold(
        body: SingleChildScrollView(
          child: StatefulBuilder(
            builder: (context, setState) => QuestionEditor(
              index: 0,
              question: question,
              isTest: isTest,
              onChanged: () => setState(() {}),
              onRemove: onRemove ?? () {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadAppFonts();
    await loadAppTranslations();
  });

  test('sanity: the fixture shape matches what the app stores', () {
    // The stored question is an untyped map, so nothing checks these keys at
    // compile time. If they drift, everything below passes while the real
    // editor writes fields the scorer never reads.
    final question = <String, dynamic>{
      'type': 'Single',
      'question': '',
      'options': ['', ''],
    };
    expect(question.containsKey('correctAnswer'), isFalse);
  });

  testWidgets('typing the question text stores it', (tester) async {
    final question = <String, dynamic>{
      'type': 'Single',
      'question': '',
      'options': ['', ''],
    };
    await _pump(tester, question, isTest: false);

    await tester.enterText(find.byType(TextFormField).first, 'Favourite tea?');
    expect(question['question'], 'Favourite tea?');
  });

  testWidgets('a survey shows letters, a test shows radio buttons', (
    tester,
  ) async {
    final question = <String, dynamic>{
      'type': 'Single',
      'question': 'Q',
      'options': ['A', 'B'],
    };

    await _pump(tester, question, isTest: false);
    expect(find.text('A'), findsWidgets);
    expect(find.byIcon(Icons.radio_button_unchecked_rounded), findsNothing);

    await _pump(tester, question, isTest: true);
    expect(find.byIcon(Icons.radio_button_unchecked_rounded), findsWidgets);
  });

  testWidgets('marking a correct answer stores its index', (tester) async {
    final question = <String, dynamic>{
      'type': 'Single',
      'question': 'Q',
      'options': ['A', 'B'],
    };
    await _pump(tester, question, isTest: true);

    await tester.tap(find.byIcon(Icons.radio_button_unchecked_rounded).last);
    await tester.pumpAndSettle();

    expect(question['correctAnswer'], 1);
  });

  testWidgets('tapping the marked answer again clears it', (tester) async {
    final question = <String, dynamic>{
      'type': 'Single',
      'question': 'Q',
      'options': ['A', 'B'],
      'correctAnswer': 0,
    };
    await _pump(tester, question, isTest: true);

    // By size, not by icon alone: the type badge uses the same glyph at 13px,
    // so `byIcon` matches two widgets and `tap` refuses an ambiguous target.
    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is Icon &&
            widget.icon == Icons.radio_button_checked_rounded &&
            widget.size == 20,
      ),
    );
    await tester.pumpAndSettle();

    expect(question['correctAnswer'], isNull);
  });

  testWidgets('multiple choice keeps every marked index, sorted', (
    tester,
  ) async {
    final question = <String, dynamic>{
      'type': 'Multiple',
      'question': 'Q',
      'options': ['A', 'B', 'C'],
      'correctAnswers': <int>[],
    };
    await _pump(tester, question, isTest: true);

    await tester.tap(find.byIcon(Icons.check_box_outline_blank_rounded).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check_box_outline_blank_rounded).first);
    await tester.pumpAndSettle();

    expect(question['correctAnswers'], [0, 2]);
  });

  group('removing an option', () {
    testWidgets('shifts a later correct answer down', (tester) async {
      // The marks are indices into the option list. The old editor kept the raw
      // index, so deleting option 0 quietly made a different answer correct.
      final question = <String, dynamic>{
        'type': 'Single',
        'question': 'Q',
        'options': ['A', 'B', 'C'],
        'correctAnswer': 2,
      };
      await _pump(tester, question, isTest: true);

      await tester.tap(find.byIcon(Icons.close_rounded).first);
      await tester.pumpAndSettle();

      expect(question['options'], ['B', 'C']);
      expect(question['correctAnswer'], 1);
    });

    testWidgets('clears the mark when the correct option is the one removed', (
      tester,
    ) async {
      final question = <String, dynamic>{
        'type': 'Single',
        'question': 'Q',
        'options': ['A', 'B'],
        'correctAnswer': 0,
      };
      await _pump(tester, question, isTest: true);

      await tester.tap(find.byIcon(Icons.close_rounded).first);
      await tester.pumpAndSettle();

      expect(question['correctAnswer'], isNull);
    });

    testWidgets('shifts multiple-choice marks too', (tester) async {
      final question = <String, dynamic>{
        'type': 'Multiple',
        'question': 'Q',
        'options': ['A', 'B', 'C'],
        'correctAnswers': [1, 2],
      };
      await _pump(tester, question, isTest: true);

      await tester.tap(find.byIcon(Icons.close_rounded).first);
      await tester.pumpAndSettle();

      expect(question['correctAnswers'], [0, 1]);
    });
  });

  testWidgets('a problem is shown against the question, not in a snackbar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(520, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        supportedLocales: AppLocales.supported,
        localizationsDelegates: const [
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        home: Scaffold(
          body: QuestionEditor(
            index: 0,
            question: const {'type': 'Text', 'question': ''},
            isTest: false,
            problem: 'question_empty_warning',
            onChanged: () {},
            onRemove: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
  });
}
