import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/settings/font_size_provider.dart';
import 'package:echomeet/survey_pages/utilities/survey_questionary_class.dart';
import 'package:echomeet/utilities/tablet_size.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

class PDFResults extends StatefulWidget {
  final Participant participant;
  final Survey survey;
  final Map<String, bool> textQuestionCorrect;

  const PDFResults({
    super.key,
    required this.participant,
    required this.survey,
    required this.textQuestionCorrect,
  });

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
    List<pw.Widget> textAnswerWidgets = [];

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
      String uniqueQuestionKey = "${widget.survey.id}-$surveyId";

      if (questionData['type'] == 'Text') {
        bool isAnswerConfirmed =
            widget.participant.textAnswersReviewed[uniqueQuestionKey] ?? false;

        pw.Widget answerDisplay = pw.Container(
          decoration: pw.BoxDecoration(
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            color: isAnswerConfirmed ? PdfColors.green : PdfColors.red300,
          ),
          padding: const pw.EdgeInsets.all(8),
          margin: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text(
                    answers.join(', '),
                    style: pw.TextStyle(
                      color:
                          isAnswerConfirmed ? PdfColors.white : PdfColors.black,
                      fontSize: 18,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        );

        textAnswerWidgets.add(
          _buildQuestionCard(question, answerDisplay, timeFontSize),
        );
      } else {
        List<pw.Widget> optionWidgets = [];

        for (int optionIndex = 0;
            optionIndex < options!.length;
            optionIndex++) {
          String option = options[optionIndex];
          bool isSelected = answers.contains(optionIndex);
          bool isCorrect = false;
          List<int>? correctAnswers =
              questionData['correctAnswers']?.cast<int>();
          int singleCorrectAnswer = questionData['correctAnswer'] ?? -1;

          if (questionData['type'] == "Single") {
            isCorrect = singleCorrectAnswer == optionIndex;
          } else if (questionData['type'] == "Multiple") {
            isCorrect =
                correctAnswers != null && correctAnswers.contains(optionIndex);
          }

          PdfColor bgColor = isCorrect
              ? PdfColors.green
              : isSelected
                  ? PdfColors.red300
                  : PdfColors.grey200;

          optionWidgets.add(
            pw.Container(
              decoration: pw.BoxDecoration(
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                color: bgColor,
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
                            color: isSelected || isCorrect
                                ? PdfColors.white
                                : PdfColors.black,
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

        pw.Widget answerDisplay = pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: optionWidgets,
        );

        answerWidgets.add(
          _buildQuestionCard(question, answerDisplay, timeFontSize),
        );
      }
    }

    pdf.addPage(
      _buildPdfPage(
          widget.participant.name, widget.participant.score, answerWidgets),
    );

    pdf.addPage(
      _buildTextAnswersPage(textAnswerWidgets),
    );

    return pdf;
  }

  pw.Widget _buildQuestionCard(
      String question, pw.Widget answerDisplay, double timeFontSize) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(
          color: PdfColors.grey,
          width: 1,
        ),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      margin: const pw.EdgeInsets.all(7),
      child: pw.Padding(
        padding: const pw.EdgeInsets.all(16),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              constraints: pw.BoxConstraints(
                minWidth: 450,
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
    );
  }

  pw.MultiPage _buildPdfPage(
      String name, double score, List<pw.Widget> answerWidgets) {
    return pw.MultiPage(
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
                  '"$name"',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  '${'total_score'.tr()} ${score.toStringAsFixed(1)}%',
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
    );
  }

  pw.MultiPage _buildTextAnswersPage(List<pw.Widget> textAnswerWidgets) {
    return pw.MultiPage(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return [
          pw.Header(
            level: 0,
            child: pw.Center(
              child: pw.Text(
                '"${'text_answers'.tr()}"',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 16, bottom: 16),
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: textAnswerWidgets,
            ),
          ),
        ];
      },
    );
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
