import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:survey_app_ks/survey_pages/utilities/survey_questionary_class.dart';
import 'package:survey_app_ks/utilities/tablet_size.dart';

import '../../../settings/font_size_provider.dart';

class PDFResults extends StatefulWidget {
  final Participant participant;
  final Survey survey;
  final Map<String, bool> textQuestionCorrect;

  const PDFResults(
      {Key? key,
      required this.participant,
      required this.survey,
      required this.textQuestionCorrect})
      : super(key: key);

  @override
  PDFResultsState createState() => PDFResultsState();
}

class PDFResultsState extends State<PDFResults> {
  pw.Document? _pdfDocument;

  @override
  void initState() {
    super.initState();
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
    var fontSizeProvider =
        Provider.of<FontSizeProvider>(context, listen: false);
    var fontSize = fontSizeProvider.fontSize;

    final timeFontSize = getTimeFontSize(context, fontSize);
    final pdf = pw.Document();

    List<pw.Widget> answerWidgets = [];

    for (int index = 0;
        index < widget.participant.surveyAnswers.length;
        index++) {
      String surveyId = widget.participant.surveyAnswers.keys.elementAt(index);
      Map<String, dynamic> questionData =
          widget.survey.questions[int.parse(surveyId.substring(1))];

      List<dynamic> answers = widget.participant.surveyAnswers[surveyId] ?? [];
      String question = questionData['question'];
      List<String>? options =
          questionData['options']?.map<String>((e) => e.toString()).toList();

      List<dynamic>? correctAnswers =
          questionData['correctAnswers'] as List<dynamic>?;
      bool isMultiCorrect = correctAnswers != null && correctAnswers.length > 1;

      pw.Widget answerDisplay;
      if (questionData['type'] == 'Text') {
        bool isAnswerConfirmed = widget.textQuestionCorrect[surveyId] ?? false;

        answerDisplay = pw.Container(
          decoration: pw.BoxDecoration(
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            color: isAnswerConfirmed ? PdfColors.green : PdfColors.red,
          ),
          padding: const pw.EdgeInsets.all(8),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  answers.join(', '),
                  style:
                      const pw.TextStyle(color: PdfColors.white, fontSize: 18),
                ),
              ),
            ],
          ),
        );
      } else {
        List<pw.Widget> optionWidgets = [];

        for (int optionIndex = 0;
            optionIndex < options!.length;
            optionIndex++) {
          String option = options[optionIndex];
          bool isSelected = answers.contains(optionIndex);
          bool isCorrect = answers.isEmpty
              ? false
              : isMultiCorrect
                  ? correctAnswers.contains(optionIndex)
                  : (correctAnswers != null &&
                      correctAnswers.length == 1 &&
                      correctAnswers[0] == optionIndex);

          optionWidgets.add(
            pw.Container(
              decoration: pw.BoxDecoration(
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                color: isCorrect
                    ? PdfColors.green
                    : isSelected
                        ? PdfColors.red
                        : PdfColors.grey200,
              ),
              padding: const pw.EdgeInsets.all(13),
              child: pw.Column(
                children: [
                  pw.Row(
                    children: [
                      pw.SizedBox(width: 16),
                      pw.Expanded(
                        child: pw.Text(
                          option,
                          style: pw.TextStyle(
                            fontSize: 18,
                            color: isSelected
                                ? PdfColors.white
                                : isCorrect
                                    ? PdfColors.black
                                    : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );

          if (optionIndex != options.length - 1) {
            optionWidgets.add(pw.SizedBox(height: 16));
          }
        }

        answerDisplay = pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: optionWidgets,
        );
      }

      answerWidgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.all(16),
          child: pw.Center(
            child: pw.Container(
              width: 500,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    constraints: pw.BoxConstraints(
                      minWidth: 400,
                      minHeight: timeFontSize * 3,
                    ),
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(16.0),
                      child: pw.Center(
                        child: pw.Text(
                          question,
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  answerDisplay,
                ],
              ),
            ),
          ),
        ),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    '"${widget.participant.name}"',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    '${'total_score'.tr()} ${widget.participant.score.toStringAsFixed(1)}%',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 16),
              child: pw.Column(children: answerWidgets),
            ),
          ];
        },
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
