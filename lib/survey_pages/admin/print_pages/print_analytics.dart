import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/survey_pages/admin/print_pages/pdf_kit.dart';
import 'package:echomeet/survey_pages/admin/print_pages/pdf_viewer_page.dart';
import 'package:echomeet/survey_pages/utilities/survey_questionary_class.dart';
import 'package:echomeet/survey_pages/utilities/survey_scoring.dart';
import 'package:flutter/widgets.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PDFAnalytics extends StatelessWidget {
  const PDFAnalytics({
    super.key,
    required this.participants,
    required this.survey,
    required this.answerCounts,
  });

  final List<Participant> participants;
  final Survey survey;

  final List<List<int>> answerCounts;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final subtitle =
        '${'participants'.tr()}: ${participants.length} · '
        '${DateFormat.yMMMd(locale).format(DateTime.now())}';

    return PdfViewerPage(
      title: 'pdf_print'.tr(),
      fileName: pdfFileNameFrom([survey.surveyName, 'analytics'.tr()]),
      build: (format) => buildDocument(format, subtitle),
    );
  }

  @visibleForTesting
  Future<pw.Document> buildDocument(
    PdfPageFormat format,
    String subtitle,
  ) async {
    final pdf = pw.Document(theme: await PdfKit.theme());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 28),
        header: (context) =>
            PdfKit.header(title: survey.surveyName, subtitle: subtitle),
        footer: PdfKit.footer,
        build: (context) => [
          for (var i = 0; i < survey.questions.length; i++) _question(i),
          if (survey.questions.isEmpty)
            pw.Text(
              'no_questions_yet'.tr(),
              style: const pw.TextStyle(fontSize: 10, color: PdfKit.muted),
            ),
        ],
      ),
    );

    return pdf;
  }

  pw.Widget _question(int index) {
    final question = survey.questions[index];
    final type = QuestionType.parse(question['type']);
    final text = (question['question'] as String? ?? '').trim();

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          PdfKit.questionHeading(index + 1, text),
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 22, top: 4),
            child: type == QuestionType.text
                ? _writtenAnswers(index)
                : _distribution(index, question),
          ),
        ],
      ),
    );
  }

  pw.Widget _distribution(int index, Map<String, dynamic> question) {
    final options = (question['options'] as List<dynamic>? ?? const [])
        .map((option) => '$option')
        .toList();

    final counts = index < answerCounts.length
        ? answerCounts[index]
        : const <int>[];
    final total = counts.fold<int>(0, (sum, count) => sum + count);

    if (total == 0) {
      return pw.Text(
        'no_responses_yet'.tr(),
        style: const pw.TextStyle(fontSize: 9, color: PdfKit.muted),
      );
    }

    final top = counts.isEmpty ? -1 : counts.indexOf(counts.reduce(_max));

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < options.length; i++)
          () {
            final count = i < counts.length ? counts[i] : 0;
            final share = count / total;

            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          options[i],
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: PdfKit.ink,
                            fontWeight: i == top
                                ? pw.FontWeight.bold
                                : pw.FontWeight.normal,
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 8),

                      pw.Text(
                        '${(share * 100).round()}%  ($count)',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfKit.muted,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 3),
                  PdfKit.bar(
                    share,
                    fill: i == top ? PdfKit.chosen : PdfColors.blueGrey200,
                  ),
                ],
              ),
            );
          }(),
      ],
    );
  }

  pw.Widget _writtenAnswers(int index) {
    final key = SurveyScorer.answerKey(index);

    final written = [
      for (final participant in participants)
        (
          name: participant.name,
          text: (participant.surveyAnswers[key] ?? const []).join(', ').trim(),
        ),
    ].where((entry) => entry.text.isNotEmpty).toList();

    if (written.isEmpty) {
      return pw.Text(
        'no_responses_yet'.tr(),
        style: const pw.TextStyle(fontSize: 9, color: PdfKit.muted),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final entry in written)
          pw.Container(
            width: double.infinity,
            margin: const pw.EdgeInsets.only(bottom: 4),
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfKit.rule, width: 0.5),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  entry.name,
                  style: const pw.TextStyle(fontSize: 7, color: PdfKit.muted),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  entry.text,
                  style: const pw.TextStyle(fontSize: 10, color: PdfKit.ink),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static int _max(int a, int b) => a > b ? a : b;
}
