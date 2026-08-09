import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/survey_pages/admin/print_pages/pdf_kit.dart';
import 'package:echomeet/survey_pages/admin/print_pages/pdf_viewer_page.dart';
import 'package:echomeet/survey_pages/utilities/survey_questionary_class.dart';
import 'package:echomeet/survey_pages/utilities/survey_scoring.dart';
import 'package:flutter/widgets.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PDFResults extends StatelessWidget {
  const PDFResults({
    super.key,
    required this.participant,
    required this.survey,
    required this.textQuestionCorrect,
  });

  final Participant participant;
  final Survey survey;
  final Map<String, bool> textQuestionCorrect;

  bool get _isTest => survey.surveyType != SurveyType.survey;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final subtitle =
        '${participant.name} · '
        '${DateFormat.yMMMd(locale).format(DateTime.now())}';

    return PdfViewerPage(
      title: 'pdf_print'.tr(),
      fileName: pdfFileNameFrom([survey.surveyName, participant.name]),
      build: (format) => buildDocument(format, subtitle),
    );
  }

  @visibleForTesting
  Future<pw.Document> buildDocument(
    PdfPageFormat format,
    String subtitle,
  ) async {
    final pdf = pw.Document(theme: await PdfKit.theme());

    final grade = SurveyScorer.grade(
      surveyId: survey.id,
      questions: survey.questions,
      answers: participant.surveyAnswers,
      textReviews: textQuestionCorrect,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 28),
        header: (context) =>
            PdfKit.header(title: survey.surveyName, subtitle: subtitle),
        footer: PdfKit.footer,
        build: (context) => [
          if (_isTest)
            PdfKit.summary([
              PdfKit.stat(
                'score'.tr(),
                '${grade.percentage.round()}%',
                tint: grade.passed ? PdfKit.correct : PdfKit.wrong,
              ),
              PdfKit.stat(
                'correct_answers'.tr(),
                '${grade.correctCount} / ${grade.gradedCount}',
              ),
              PdfKit.stat(
                'result'.tr(),
                grade.passed ? 'passed'.tr() : 'not_passed'.tr(),
                tint: grade.passed ? PdfKit.correct : PdfKit.wrong,
              ),
            ]),

          for (var i = 0; i < survey.questions.length; i++) _question(i, grade),
        ],
      ),
    );

    return pdf;
  }

  pw.Widget _question(int index, SurveyGrade grade) {
    final question = survey.questions[index];
    final key = SurveyScorer.answerKey(index);
    final answer = participant.surveyAnswers[key] ?? const [];
    final type = QuestionType.parse(question['type']);
    final text = (question['question'] as String? ?? '').trim();

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 14),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          PdfKit.questionHeading(index + 1, text),
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 22),
            child: switch (type) {
              QuestionType.text => _textAnswer(index, answer),
              _ => _options(question, answer, type),
            },
          ),
        ],
      ),
    );
  }

  pw.Widget _options(
    Map<String, dynamic> question,
    List<dynamic> answer,
    QuestionType type,
  ) {
    final options = (question['options'] as List<dynamic>? ?? const [])
        .map((option) => '$option')
        .toList();

    final correct = <int>{
      if (type == QuestionType.single && question['correctAnswer'] is int)
        question['correctAnswer'] as int,
      if (type == QuestionType.multiple)
        ...((question['correctAnswers'] as List<dynamic>? ?? const [])
            .whereType<int>()),
    };

    final graded = _isTest && correct.isNotEmpty;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < options.length; i++)
          () {
            final picked = answer.contains(i);
            final isRight = correct.contains(i);

            final (chip, fill, tag) = switch ((graded, picked, isRight)) {
              (true, true, true) => (
                PdfKit.correct,
                PdfKit.correctFill,
                'chosen_correct'.tr(),
              ),
              (true, true, false) => (
                PdfKit.wrong,
                PdfKit.wrongFill,
                'chosen_wrong'.tr(),
              ),

              (true, false, true) => (PdfKit.correct, null, 'missed'.tr()),
              (false, true, _) => (PdfKit.chosen, null, 'chosen'.tr()),
              _ => (PdfKit.rule, null, null),
            };

            return PdfKit.row(
              text: options[i],
              tag: tag,
              chipColor: chip,
              fill: fill,
              picked: picked,
              lostMark: graded && picked != isRight,
            );
          }(),
        if (answer.isEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Text(
              'no_answer_given'.tr(),
              style: const pw.TextStyle(fontSize: 9, color: PdfKit.muted),
            ),
          ),
      ],
    );
  }

  pw.Widget _textAnswer(int index, List<dynamic> answer) {
    final written = answer.join(', ').trim();
    final key = '${survey.id}-${SurveyScorer.answerKey(index)}';
    final marked = textQuestionCorrect[key];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: double.infinity,
          margin: const pw.EdgeInsets.only(top: 4),
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfKit.rule, width: 0.5),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Text(
            written.isEmpty ? 'no_answer_given'.tr() : written,
            style: pw.TextStyle(
              fontSize: 10,
              color: written.isEmpty ? PdfKit.muted : PdfKit.ink,
            ),
          ),
        ),
        if (_isTest)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Text(
              switch (marked) {
                true => 'marked_correct'.tr(),
                false => 'marked_incorrect'.tr(),
                null => 'awaiting_review'.tr(),
              },
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: switch (marked) {
                  true => PdfKit.correct,
                  false => PdfKit.wrong,
                  null => PdfKit.muted,
                },
              ),
            ),
          ),
      ],
    );
  }
}
