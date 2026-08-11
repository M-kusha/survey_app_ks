import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/survey_pages/admin/print_pages/pdf_kit.dart';
import 'package:echomeet/survey_pages/admin/print_pages/pdf_viewer_page.dart';
import 'package:echomeet/survey_pages/utilities/survey_questionary_class.dart';
import 'package:echomeet/survey_pages/utilities/survey_scoring.dart';
import 'package:flutter/widgets.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class GroupResultsPdf extends StatelessWidget {
  const GroupResultsPdf({
    super.key,
    required this.survey,
    required this.participants,
    required this.groupLabel,
  });

  final Survey survey;
  final List<Participant> participants;

  final String groupLabel;

  @override
  Widget build(BuildContext context) {
    return PdfViewerPage(
      title: 'export_results'.tr(),
      fileName: pdfFileNameFrom([survey.surveyName, groupLabel]),
      build: buildDocument,
    );
  }

  @visibleForTesting
  Future<pw.Document> buildDocument(PdfPageFormat format) async {
    final pdf = pw.Document(theme: await PdfKit.theme());
    final questionCount = survey.questions.length;

    final rows = [...participants]
      ..sort((a, b) {
        final aFinal = _grade(a).resultIsFinal;
        final bFinal = _grade(b).resultIsFinal;
        if (aFinal != bFinal) return aFinal ? -1 : 1;
        return b.score.compareTo(a.score);
      });
    final finalRows = rows.where((row) => _grade(row).resultIsFinal).toList();

    final average = finalRows.isEmpty
        ? null
        : finalRows.map((p) => p.score).reduce((a, b) => a + b) /
              finalRows.length;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: format,
        header: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 12),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                survey.surveyName,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                '$groupLabel · '
                '${'participants'.tr()}: ${rows.length} · '
                '${'average'.tr()}: '
                '${average == null ? '—' : '${average.round()}%'}',
                style: const pw.TextStyle(fontSize: 10),
              ),
              if (rows.isNotEmpty) ...[
                pw.SizedBox(height: 10),
                _resultRow(
                  values: [
                    '#',
                    'name'.tr(),
                    'score'.tr(),
                    'correct_answers'.tr(),
                  ],
                  isHeader: true,
                ),
              ],
            ],
          ),
        ),

        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            '${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ),
        build: (context) => [
          for (var i = 0; i < rows.length; i++)
            () {
              final grade = _grade(rows[i]);
              return _resultRow(
                values: [
                  '${i + 1}',
                  rows[i].auditLabel('unknown'.tr()),
                  grade.resultIsFinal
                      ? '${rows[i].score.round()}%'
                      : _nonFinalLabel(grade),
                  grade.scoreAvailable
                      ? '${rows[i].totalCorrectAnswers} / '
                            '${rows[i].gradedQuestionCount ?? questionCount}'
                      : '—',
                ],
              );
            }(),
          if (rows.isEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 24),
              child: pw.Text('no_participants_added_yet'.tr()),
            ),
        ],
      ),
    );

    return pdf;
  }

  SurveyGrade _grade(Participant participant) =>
      SurveyScorer.authoritativeGrade(
        surveyId: survey.id,
        questions: survey.questions,
        answers: participant.surveyAnswers,
        score: participant.score,
        correctCount: participant.totalCorrectAnswers,
        gradedCount: participant.gradedQuestionCount,
        gradingStatus: participant.gradingStatus,
        textReviews: participant.textAnswersReviewed,
      );

  String _nonFinalLabel(SurveyGrade grade) {
    if (grade.isProcessing) return 'grading_processing'.tr();
    if (grade.hasPendingReview) return 'awaiting_review'.tr();
    return 'grading_error'.tr();
  }

  pw.Widget _resultRow({required List<String> values, bool isHeader = false}) {
    const borderSide = pw.BorderSide(width: 0.5);
    final textStyle = pw.TextStyle(
      fontSize: 10,
      fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
    );

    pw.Widget cell(
      String value, {
      double? width,
      required pw.Alignment alignment,
      bool drawRightBorder = true,
    }) {
      final content = pw.Container(
        width: width,
        height: 22,
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        alignment: alignment,
        decoration: pw.BoxDecoration(
          border: pw.Border(
            right: drawRightBorder ? borderSide : pw.BorderSide.none,
          ),
        ),
        child: pw.FittedBox(
          fit: pw.BoxFit.scaleDown,
          alignment: alignment,
          child: pw.Text(value, maxLines: 1, style: textStyle),
        ),
      );

      return width == null ? pw.Expanded(child: content) : content;
    }

    return pw.Container(
      height: 22,
      decoration: pw.BoxDecoration(
        border: pw.Border(
          left: borderSide,
          right: borderSide,
          top: isHeader ? borderSide : pw.BorderSide.none,
          bottom: borderSide,
        ),
      ),
      child: pw.Row(
        children: [
          cell(values[0], width: 36, alignment: pw.Alignment.centerLeft),
          cell(values[1], alignment: pw.Alignment.centerLeft),
          cell(values[2], width: 56, alignment: pw.Alignment.centerRight),
          cell(
            values[3],
            width: 72,
            alignment: pw.Alignment.centerRight,
            drawRightBorder: false,
          ),
        ],
      ),
    );
  }
}
