import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/survey_pages/utilities/survey_questionary_class.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PDFAnalytics extends StatefulWidget {
  final List<Participant> participants;
  final Survey survey;
  final List<List<int>> answerCounts;

  const PDFAnalytics({
    Key? key,
    required this.participants,
    required this.survey,
    required this.answerCounts,
  }) : super(key: key);

  @override
  PdfGenerationPageState createState() => PdfGenerationPageState();
}

class PdfGenerationPageState extends State<PDFAnalytics> {
  List<List<int>> answerCounts = [];
  pw.Document? _pdfDocument;
  double percentage = 0;

  @override
  void initState() {
    super.initState();
    answerCounts = widget.answerCounts;

    Future.microtask(() {
      _generatePdf().then((pdfDocument) {
        setState(() {
          _pdfDocument = pdfDocument;
        });
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pdfDocument == null) {
      _generatePdf().then((pdfDocument) {
        setState(() {
          _pdfDocument = pdfDocument;
        });
      });
    }
  }

  Future<pw.Document> _generatePdf() async {
    final pdf = pw.Document();

    final textStyle = pw.TextStyle(
      fontSize: 16,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.blueGrey,
    );

    final optionTextStyle = pw.TextStyle(
      fontSize: 16,
      fontWeight: pw.FontWeight.normal,
      color: PdfColors.black,
    );

    const borderColor = PdfColors.grey300;

    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(20),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Center(
              child: pw.Text(
                '${'analytics_off'.tr()} ${widget.survey.surveyName}',
                style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey),
              ),
            ),
          ),
          pw.SizedBox(height: 20),
          ...widget.survey.questions.asMap().entries.map((entry) {
            int questionIndex = entry.key;
            Map<String, dynamic> questionData = entry.value;

            List<String> options = List<String>.from(questionData['options']);
            int totalVotesForQuestion = widget.answerCounts[questionIndex]
                .reduce((sum, item) => sum + item);

            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 20),
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: borderColor, width: 2),
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Padding(
                  padding: const pw.EdgeInsets.all(20),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Center(
                        child: pw.Text(
                          questionData['question'],
                          style: textStyle,
                        ),
                      ),
                      pw.Divider(),
                      ...options.asMap().entries.map((optionEntry) {
                        int optionIndex = optionEntry.key;
                        String option = optionEntry.value;
                        int voteCount =
                            widget.answerCounts[questionIndex][optionIndex];
                        double percentage = totalVotesForQuestion > 0
                            ? (voteCount / totalVotesForQuestion) * 100
                            : 0;

                        return pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                              vertical: 5,
                              horizontal:
                                  10), // Adjust container padding as needed
                          child: pw.Container(
                            height: 40,
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(
                                color: borderColor,
                                width: 2,
                              ),
                              borderRadius: pw.BorderRadius.circular(10),
                            ),
                            child: pw.Row(
                              mainAxisAlignment:
                                  pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Padding(
                                  padding: const pw.EdgeInsets.only(
                                      left:
                                          10), // Adjust text padding as needed
                                  child: pw.Text(
                                    option,
                                    style: optionTextStyle,
                                  ),
                                ),
                                pw.Container(
                                  width: 160, // Adjust progress bar width
                                  height: 20,
                                  decoration: pw.BoxDecoration(
                                    color: percentage >= 75
                                        ? PdfColors.green
                                        : percentage >= 50
                                            ? PdfColors.blueGrey
                                            : percentage >= 25
                                                ? PdfColors.orange
                                                : PdfColors.red,
                                    borderRadius: pw.BorderRadius.circular(5),
                                  ),
                                  child: pw.Stack(
                                    children: [
                                      pw.Positioned.fill(
                                        child: pw.Container(
                                          width: (percentage / 100) *
                                              160, // Adjust progress bar width
                                        ),
                                      ),
                                      pw.Center(
                                        child: pw.Row(
                                          mainAxisAlignment:
                                              pw.MainAxisAlignment.spaceEvenly,
                                          children: [
                                            pw.Text(
                                              '${percentage.toStringAsFixed(1)}%',
                                              style: optionTextStyle,
                                            ),
                                            pw.Text(
                                              '($voteCount)',
                                              style: optionTextStyle,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );

    return pdf;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('pdf_print'.tr()),
        centerTitle: true,
      ),
      body: _pdfDocument == null
          ? const Center(child: CircularProgressIndicator())
          : PdfPreview(
              build: (format) => _pdfDocument!.save(),
            ),
    );
  }
}
