import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/survey_pages/admin/print_pages/pdf_viewer_page.dart';
import 'package:echomeet/survey_pages/utilities/survey_questionary_class.dart';
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
      build: _build,
    );
  }

  Future<pw.Document> _build(PdfPageFormat format) async {
    final pdf = pw.Document();
    final questionCount = survey.questions.length;

    final rows = [...participants]..sort((a, b) => b.score.compareTo(a.score));

    final average = rows.isEmpty
        ? 0.0
        : rows.map((p) => p.score).reduce((a, b) => a + b) / rows.length;

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
                '${'average'.tr()}: ${average.round()}%',
                style: const pw.TextStyle(fontSize: 10),
              ),
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
          pw.TableHelper.fromTextArray(
            headers: ['#', 'name'.tr(), 'score'.tr(), 'correct_answers'.tr()],
            data: [
              for (var i = 0; i < rows.length; i++)
                [
                  '${i + 1}',
                  rows[i].name,
                  '${rows[i].score.round()}%',
                  '${rows[i].totalCorrectAnswers} / $questionCount',
                ],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
            },
            cellStyle: const pw.TextStyle(fontSize: 10),
          ),
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
}
