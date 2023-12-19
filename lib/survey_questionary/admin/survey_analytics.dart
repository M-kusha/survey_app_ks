import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:survey_app_ks/settings/font_size_provider.dart';
import 'package:survey_app_ks/survey_questionary/utilities/survey_questionary_class.dart';
import 'package:survey_app_ks/utilities/tablet_size.dart';

class SurveyAnalyticsPage extends StatefulWidget {
  final List<Participant> participants;
  final SurveyQuestionaryType survey;

  const SurveyAnalyticsPage({
    Key? key,
    required this.participants,
    required this.survey,
  }) : super(key: key);

  @override
  SurveyAnalyticsPageState createState() => SurveyAnalyticsPageState();
}

class SurveyAnalyticsPageState extends State<SurveyAnalyticsPage> {
  List<List<int>> _answerCounts = [];

  @override
  void initState() {
    super.initState();
    _calculateAnswerCounts();
  }

  List<String> safeStringListFromDynamic(dynamic list) {
    if (list is! List) return []; // Return an empty list if it's not a list
    return list.map((item) => item.toString()).toList();
  }

  void _calculateAnswerCounts() {
    _answerCounts = List.generate(
      widget.survey.questions.length,
      (index) {
        Map<String, dynamic> questionData = widget.survey.questions[index];
        List<String> options =
            safeStringListFromDynamic(questionData['options']);

        return List.generate(options.length, (index) => 0);
      },
    );

    for (var participant in widget.participants) {
      participant.surveyAnswers.forEach((surveyId, answers) {
        int questionIndex = int.parse(surveyId.substring(1));
        for (var answerIndex in answers) {
          try {
            _answerCounts[questionIndex][answerIndex]++;
            // ignore: empty_catches
          } catch (e) {}
        }
      });
    }
  }

  Color? _textColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? const Color(0xFF004B96)
        : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(timeFontSize * 0.5),
            child: widget.participants.isNotEmpty
                ? Row(
                    children: [
                      Text(
                        '${'number_of_participants'.tr()} ${widget.participants.length}',
                        style: TextStyle(
                          fontSize: timeFontSize,
                          fontWeight: FontWeight.bold,
                          color:
                              Theme.of(context).brightness == Brightness.light
                                  ? const Color(0xFF004B96)
                                  : Colors.white,
                        ),
                      ),

                      // create me a printing button
                      IconButton(
                        onPressed: () async {
                          final pdf = await _generatePdf();
                          await Printing.layoutPdf(
                            onLayout: (PdfPageFormat format) async =>
                                pdf.save(),
                          );
                        },
                        icon: const Icon(Icons.print),
                      )
                    ],
                  )
                : null,
          ),
          Expanded(
            child: widget.participants.isEmpty
                ? Center(
                    child: Text('no_participants_added_yet'.tr()),
                  )
                : ListView.builder(
                    itemCount: widget.survey.questions.length,
                    itemBuilder: (context, questionIndex) {
                      Map<String, dynamic> questionData =
                          widget.survey.questions[questionIndex];
                      String question = questionData['question'];
                      String questionType = questionData['type'];
                      List<String>? options =
                          questionData['options'] as List<String>? ??
                              ['True', 'False'];

                      if (questionType == 'Text') {
                        return const SizedBox.shrink();
                      }

                      return Padding(
                        padding: const EdgeInsets.only(
                          left: 16,
                          right: 16,
                          top: 16,
                          bottom: 8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              constraints: BoxConstraints(
                                minWidth: double.infinity,
                                minHeight: timeFontSize * 3,
                              ),
                              child: Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                    question,
                                    style: TextStyle(
                                      fontSize: timeFontSize,
                                      fontWeight: FontWeight.bold,
                                      color: _textColor(context),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),
                            Card(
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: options.length,
                                itemBuilder: (context, optionIndex) {
                                  String option = options[optionIndex];
                                  int count =
                                      _answerCounts[questionIndex][optionIndex];
                                  double percentage =
                                      (count / widget.participants.length) *
                                          100;

                                  return ListTile(
                                    title: Text(
                                      option,
                                      style: TextStyle(
                                        fontSize: timeFontSize,
                                        fontWeight: FontWeight.bold,
                                        color: _textColor(context),
                                      ),
                                    ),
                                    trailing: Text(
                                      '(${percentage.toStringAsFixed(1)}%)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: timeFontSize,
                                        color: _textColor(context),
                                      ),
                                    ),
                                    subtitle: LinearProgressIndicator(
                                      value: percentage / 100,
                                      backgroundColor: Colors.grey[300],
                                      color: Theme.of(context).brightness ==
                                              Brightness.light
                                          ? const Color(0xFF004B96)
                                          : Colors.green,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<pw.Document> _generatePdf() async {
    final pdf = pw.Document();

    // Add a header with the survey name
    pdf.addPage(
      pw.Page(
        build: (context) => pw.Header(
          level: 0,
          child: pw.Text(
            'Survey Name', // Replace 'Survey Name' with the actual survey name
            style: pw.TextStyle(
              fontSize: 28,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      ),
    );

    for (int questionIndex = 0;
        questionIndex < widget.survey.questions.length;
        questionIndex++) {
      Map<String, dynamic> questionData =
          widget.survey.questions[questionIndex];
      String question = questionData['question'];
      String questionType = questionData['type'];
      List<String>? options =
          questionData['options'] as List<String>? ?? ['True', 'False'];

      if (questionType == 'Text') {
        continue;
      }

      pdf.addPage(
        pw.MultiPage(
          build: (context) => [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 16),
              child: pw.Center(
                child: pw.Text(
                  question,
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ),
            pw.ListView(
              children: options.map((option) {
                int count =
                    _answerCounts[questionIndex][options.indexOf(option)];
                double percentage = (count / widget.participants.length) * 100;

                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          option,
                          style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Stack(
                          children: [
                            pw.Container(
                              height: 32,
                              width: percentage * 3.2,
                              color: PdfColors.green,
                            ),
                            pw.Positioned.fill(
                              child: pw.Center(
                                child: pw.Text(
                                  '${percentage.toStringAsFixed(1)}%',
                                  style: pw.TextStyle(
                                    fontSize: 20,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      );
    }

    return pdf;
  }
}
