import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:echomeet/survey_pages/admin/print_pages/group_results_pdf.dart';
import 'package:echomeet/survey_pages/admin/print_pages/pdf_binary.dart';
import 'package:echomeet/survey_pages/admin/print_pages/pdf_kit.dart';
import 'package:echomeet/survey_pages/admin/print_pages/print_analytics.dart';
import 'package:echomeet/survey_pages/admin/print_pages/print_results.dart';
import 'package:echomeet/survey_pages/utilities/survey_questionary_class.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'support/load_translations.dart';

String _boundedWords(int length, String sentinel) {
  final bodyLength = length - sentinel.length;
  final words = List.filled((bodyLength / 5).ceil() + 1, 'word ').join();
  return '${words.substring(0, bodyLength)}$sentinel';
}

int _pdfPageCount(Uint8List bytes) => RegExp(
  r'/Type/Page(?!s)',
).allMatches(latin1.decode(bytes, allowInvalid: true)).length;

/// Extracts the embedded Inter text used by these exports.
///
/// This deliberately reads the finalized bytes rather than the input model,
/// so a clipped maxLines value or a widget that never reaches a later page
/// loses its terminal sentinel and fails the test.
String _extractPdfText(Uint8List bytes) {
  final source = latin1.decode(bytes, allowInvalid: true);
  final objects = <int, String>{};
  final headers = RegExp(r'(\d+) 0 obj').allMatches(source).toList();

  for (var index = 0; index < headers.length; index++) {
    final header = headers[index];
    final end = index + 1 < headers.length
        ? headers[index + 1].start
        : source.length;
    final object = source.substring(header.end, end);
    final marker = RegExp(r'stream\r?\n').firstMatch(object);
    if (marker == null ||
        !object.substring(0, marker.start).contains('/FlateDecode')) {
      continue;
    }
    final lengths = RegExp(
      r'/Length\s+(\d+)',
    ).allMatches(object.substring(0, marker.start)).toList();
    if (lengths.isEmpty) continue;
    final length = int.parse(lengths.last.group(1)!);
    final start = header.end + marker.end;
    objects[int.parse(header.group(1)!)] = latin1.decode(
      ZLibDecoder().convert(bytes.sublist(start, start + length)),
      allowInvalid: true,
    );
  }

  final fonts = <String, Map<int, String>>{};
  for (final match in RegExp(
    r'/Name/(F\d+)[\s\S]{0,600}?/ToUnicode\s+(\d+)\s+0\s+R',
  ).allMatches(source)) {
    final cmap = objects[int.parse(match.group(2)!)] ?? '';
    fonts[match.group(1)!] = {
      for (final pair in RegExp(
        r'<([0-9A-Fa-f]{4})>\s+<([0-9A-Fa-f]+)>',
      ).allMatches(cmap))
        int.parse(pair.group(1)!, radix: 16): String.fromCharCodes([
          for (var offset = 0; offset < pair.group(2)!.length; offset += 4)
            int.parse(pair.group(2)!.substring(offset, offset + 4), radix: 16),
        ]),
    };
  }

  final extracted = StringBuffer();
  for (final stream in objects.values.where((value) => value.contains('BT'))) {
    String? font;
    for (final token in RegExp(
      r'/(F\d+)\s+[\d.]+\s+Tf|<([0-9A-Fa-f]+)>',
    ).allMatches(stream)) {
      if (token.group(1) case final selected?) {
        font = selected;
        continue;
      }
      final encoded = token.group(2)!;
      final cmap = fonts[font];
      if (cmap == null || encoded.length.isOdd) continue;
      for (var offset = 0; offset + 4 <= encoded.length; offset += 4) {
        extracted.write(
          cmap[int.parse(encoded.substring(offset, offset + 4), radix: 16)],
        );
      }
    }
  }
  return extracted.toString();
}

/// Smoke tests for the exports.
///
/// A PDF layout error is invisible until somebody presses download: it is not a
/// compile error, `flutter analyze` cannot see it, and the failure arrives as a
/// blank viewer in front of whoever needed the results. These build real
/// documents and assert bytes come out.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => loadAppTranslations());

  /// The awkward survey: a single choice, a multiple choice and a free-text
  /// question, one unanswered question, and an option nobody picked. Every
  /// branch of the option-marking switch is reachable from this one fixture.
  Survey surveyOf(SurveyType type) => Survey(
    id: 's1',
    surveyName: 'Quarterly review - Prüfung ë ç',
    surveyDescription: 'd',
    companyId: 'c1',
    timeCreated: DateTime(2026, 1, 1),
    deadline: DateTime(2026, 12, 31),
    surveyType: type,
    participants: [],
    questions: [
      {
        'type': 'Single',
        'question': 'Which is correct?',
        'options': ['A', 'B', 'C'],
      },
      {
        'type': 'Multiple',
        'question': 'Pick the right ones',
        'options': ['A', 'B', 'C'],
      },
      {'type': 'Text', 'question': 'Explain your reasoning'},
      {
        'type': 'Single',
        'question': 'Nobody answered this one',
        'options': ['A', 'B'],
      },
    ],
  );

  final participant = Participant(
    userId: 'u1',
    // The response snapshot differs on purpose: authorized rendering must use
    // the current directory name below, not this historical value.
    name: 'Historical Çabej-Ümlaut',
    surveyAnswers: {
      'Q0': [0],
      'Q1': [0, 2],
      'Q2': ['Because it seemed right'],
    },
    score: 50,
    textAnswersReviewed: {'s1-Q2': true},
    totalCorrectAnswers: 1,
    gradedQuestionCount: 4,
    gradingStatus: 'final',
  )..resolveDirectoryIdentity('Kushtrim Çabej-Ümlaut');

  test('participant export attribution keeps the authoritative UID', () {
    expect(participant.auditLabel(), 'Kushtrim Çabej-Ümlaut · UID u1');
    final retained = Participant(
      userId: 'retained-user',
      name: 'Historical snapshot',
      surveyAnswers: const {},
      score: 0,
    )..resolveDirectoryIdentity(null);
    expect(retained.auditLabel(), 'Unknown · UID retained-user');
    retained.resolveDirectoryIdentity('Current canonical name');
    expect(retained.auditLabel(), 'Current canonical name · UID retained-user');
  });

  test('theme embeds the app font', () async {
    final theme = await PdfKit.theme();
    expect(theme, isNotNull);

    // Cached, not reparsed. Three TTFs per export is real work on a document
    // somebody is waiting for.
    expect(identical(await PdfKit.theme(), theme), isTrue);
  });

  test('a test paper generates', () async {
    final pdf = pw.Document(theme: await PdfKit.theme());
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) =>
            PdfKit.header(title: 'Quarterly review', subtitle: 'x'),
        footer: PdfKit.footer,
        build: (context) => [
          PdfKit.summary([
            PdfKit.stat('Score', '50%', tint: PdfKit.wrong),
            PdfKit.stat('Correct', '1 / 4'),
          ]),
          PdfKit.questionHeading(1, 'Which is correct?'),
          PdfKit.row(text: 'A', tag: 'correct', chipColor: PdfKit.correct),
          PdfKit.row(text: 'B', tag: null),
          // Both ends of the bar, which is where a flex of zero would throw.
          PdfKit.bar(0),
          PdfKit.bar(0.5),
          PdfKit.bar(1),
          // The shape the written-answer box uses. `double.infinity` resolves
          // against the page in a MultiPage; it would be unbounded and throw in
          // a Row, so it is worth pinning where it is actually used.
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(8),
            child: pw.Text(participant.name),
          ),
        ],
      ),
    );

    expect((await pdf.save()).length, greaterThan(1000));
  });

  /// A PDF reader will not open a file whose trailer is missing, and the pdf
  /// package will happily hand back bytes that look like a document. "We can't
  /// open this file" is what that looks like from the other end.
  void expectValidPdf(Uint8List bytes, String label) {
    expect(bytes.length, greaterThan(1000), reason: '$label is too small');

    final head = String.fromCharCodes(bytes.take(8));
    expect(head, startsWith('%PDF-'), reason: '$label has no PDF header');

    final tail = String.fromCharCodes(bytes.skip(bytes.length - 32));
    expect(tail, contains('%%EOF'), reason: '$label has no trailer');

    // Written out so a failure can be opened by hand rather than guessed at.
    File(
      '${Directory.systemTemp.path}/echomeet-$label.pdf',
    ).writeAsBytesSync(bytes);
  }

  test('the real participant sheet is a valid PDF', () async {
    final widget = PDFResults(
      participant: participant,
      survey: surveyOf(SurveyType.test),
      textQuestionCorrect: participant.textAnswersReviewed,
    );

    final document = await widget.buildDocument(
      PdfPageFormat.a4,
      participant.auditLabel(),
    );
    final bytes = await finalizePdfDocument(document);
    expectValidPdf(bytes, 'participant');
    final text = _extractPdfText(bytes);
    expect(text, contains('KushtrimÇabej-Ümlaut·UIDu1'));
    expect(text, isNot(contains('HistoricalÇabej-Ümlaut')));
  });

  test('a survey sheet is a valid PDF', () async {
    // The ungraded path: no summary strip, no right answers, and the option
    // marking switch takes a different branch throughout.
    final widget = PDFResults(
      participant: participant,
      survey: surveyOf(SurveyType.survey),
      textQuestionCorrect: const {},
    );

    final document = await widget.buildDocument(
      PdfPageFormat.a4,
      participant.auditLabel(),
    );
    final bytes = await finalizePdfDocument(document);
    expectValidPdf(bytes, 'survey');
    final text = _extractPdfText(bytes);
    expect(text, contains('KushtrimÇabej-Ümlaut·UIDu1'));
    expect(text, isNot(contains('HistoricalÇabej-Ümlaut')));
  });

  test('the analytics report is a valid PDF', () async {
    final survey = surveyOf(SurveyType.survey);
    final widget = PDFAnalytics(
      survey: survey,
      participants: [participant],
      answerCounts: const [
        [1, 0, 0],
        [1, 0, 1],
        // A free-text question, which the old builder threw on.
        [],
        [0, 0],
      ],
    );

    final document = await widget.buildDocument(PdfPageFormat.a4, 'subtitle');
    final bytes = await finalizePdfDocument(document);
    expectValidPdf(bytes, 'analytics');
    final text = _extractPdfText(bytes);
    expect(text, contains('KushtrimÇabej-Ümlaut·UIDu1'));
    expect(text, isNot(contains('HistoricalÇabej-Ümlaut')));
  });

  test('the multi-page group report is a valid PDF', () async {
    final participants = List.generate(120, (index) {
      final name = 'Teilnehmer $index - Kushtrim Çabej-Ümlaut ë ç';
      return Participant(
        userId: 'u$index',
        name: name,
        surveyAnswers: const {},
        score: (index % 101).toDouble(),
        textAnswersReviewed: const {},
        totalCorrectAnswers: index % 4,
      )..resolveDirectoryIdentity(name);
    });
    final widget = GroupResultsPdf(
      survey: surveyOf(SurveyType.test),
      participants: participants,
      groupLabel: 'Alle Teilnehmenden - Të gjithë pjesëmarrësit',
    );

    final document = await widget.buildDocument(PdfPageFormat.a4);
    final bytes = await finalizePdfDocument(document);
    expectValidPdf(bytes, 'group');
    expect(_extractPdfText(bytes), contains('UIDu0'));
  });

  test(
    'a deleted directory member keeps a neutral label and UID in PDF',
    () async {
      final retained = Participant(
        userId: 'retained-user',
        name: 'Historical snapshot must not render',
        surveyAnswers: const {},
        score: 0,
        gradingStatus: 'error',
      )..resolveDirectoryIdentity(null);
      final document = await GroupResultsPdf(
        survey: surveyOf(SurveyType.test),
        participants: [retained],
        groupLabel: 'Retained results',
      ).buildDocument(PdfPageFormat.a4);
      final bytes = await finalizePdfDocument(document);

      expectValidPdf(bytes, 'retained-identity');
      final text = _extractPdfText(bytes);
      expect(text, contains('Unknown'));
      expect(text, contains('UIDretained-user'));
      expect(text, isNot(contains('Historicalsnapshotmustnotrender')));
    },
  );
  test('accepted max text spans participant and analytics pages', () async {
    const titleEnd = 'TITLE-END-7K';
    const questionEnd = 'QUESTION-END-8K';
    const optionEnd = 'OPTION-END-9K';
    const answerEnd = 'ANSWER-END-6K';
    const nameEnd = 'NAME-END-5K';
    final title = _boundedWords(160, titleEnd);
    final question = _boundedWords(4000, questionEnd);
    final option = _boundedWords(1000, optionEnd);
    final answer = _boundedWords(5999, answerEnd);
    final name = _boundedWords(120, nameEnd);
    final survey = Survey(
      id: 'max-pdf',
      surveyName: title,
      surveyDescription: '',
      companyId: 'c1',
      timeCreated: DateTime(2026, 1, 1),
      deadline: DateTime(2026, 12, 31),
      surveyType: SurveyType.survey,
      participants: const [],
      questions: [
        {'type': 'Text', 'question': question},
        {
          'type': 'Single',
          'question': 'Bounded option',
          'options': [option, 'Other'],
        },
      ],
    );
    final maximalParticipant = Participant(
      userId: 'max-user',
      name: name,
      surveyAnswers: {
        'Q0': [answer],
        'Q1': [0],
      },
      score: 0,
    )..resolveDirectoryIdentity(name);

    expect(title, hasLength(160));
    expect(question, hasLength(4000));
    expect(option, hasLength(1000));
    expect(answer, hasLength(5999));
    expect(name, hasLength(120));

    final participantBytes = await finalizePdfDocument(
      await PDFResults(
        participant: maximalParticipant,
        survey: survey,
        textQuestionCorrect: const {},
      ).buildDocument(PdfPageFormat.a4, 'participant subtitle'),
    );
    expectValidPdf(participantBytes, 'max-participant');
    expect(_pdfPageCount(participantBytes), greaterThan(1));
    final participantText = _extractPdfText(participantBytes);
    for (final sentinel in [titleEnd, questionEnd, optionEnd, answerEnd]) {
      expect(participantText, contains(sentinel));
    }

    final analyticsBytes = await finalizePdfDocument(
      await PDFAnalytics(
        participants: [maximalParticipant],
        survey: survey,
        answerCounts: const [
          [],
          [1, 0],
        ],
      ).buildDocument(PdfPageFormat.a4, 'analytics subtitle'),
    );
    expectValidPdf(analyticsBytes, 'max-analytics');
    expect(_pdfPageCount(analyticsBytes), greaterThan(1));
    final analyticsText = _extractPdfText(analyticsBytes);
    for (final sentinel in [
      titleEnd,
      questionEnd,
      optionEnd,
      answerEnd,
      nameEnd,
    ]) {
      expect(analyticsText, contains(sentinel));
    }
  });

  test('max group and participant names wrap without shrinking', () async {
    const groupEnd = 'GROUP-END-4K';
    const nameEnd = 'ROW-NAME-END-3K';
    final group = _boundedWords(120, groupEnd);
    final name = _boundedWords(120, nameEnd);
    final maximalParticipant = Participant(
      userId: 'max-row-user',
      name: name,
      surveyAnswers: const {},
      score: 50,
      textAnswersReviewed: const {},
      totalCorrectAnswers: 1,
      gradedQuestionCount: 4,
      gradingStatus: 'final',
    )..resolveDirectoryIdentity(name);
    final document = await GroupResultsPdf(
      survey: surveyOf(SurveyType.test),
      participants: [maximalParticipant],
      groupLabel: group,
    ).buildDocument(PdfPageFormat.a4);
    final bytes = await finalizePdfDocument(document);

    expectValidPdf(bytes, 'max-group-names');
    final text = _extractPdfText(bytes);
    expect(text, contains(groupEnd));
    expect(text, contains(nameEnd));
  });

  test('fixtures cover both survey kinds', () {
    // Guards the fixture itself: if `SurveyType` grows a case, this is the
    // reminder that the exports have a third shape to handle.
    expect(SurveyType.values, hasLength(2));
    expect(surveyOf(SurveyType.test).questions, hasLength(4));
    expect(participant.surveyAnswers.containsKey('Q3'), isFalse);
  });
}
