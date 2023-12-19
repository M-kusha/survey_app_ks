import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:survey_app_ks/settings/font_size_provider.dart';
import 'package:survey_app_ks/survey_questionary/admin/survey_participants.dart';
import 'package:survey_app_ks/survey_questionary/utilities/survey_questionary_class.dart';
import 'package:survey_app_ks/utilities/tablet_size.dart';

class ParticipantAnswersPage extends StatefulWidget {
  final Participant participant;
  final SurveyQuestionaryType survey;
  final ScoreData scoreData;

  const ParticipantAnswersPage({
    Key? key,
    required this.participant,
    required this.survey,
    required this.scoreData,
  }) : super(key: key);

  @override
  ParticipantAnswersPageState createState() => ParticipantAnswersPageState();
}

class ParticipantAnswersPageState extends State<ParticipantAnswersPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Participant> participants = [];

  Map<String, bool> textQuestionCorrect = {};
  Color? _textColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? const Color(0xFF004B96)
        : Colors.white;
  }

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() {});

    String userId = _auth.currentUser!.uid;

    Future<DocumentSnapshot> fetchUserFuture =
        FirebaseFirestore.instance.collection('users').doc(userId).get();

    Future<QuerySnapshot> fetchQuestionsFuture = FirebaseFirestore.instance
        .collection('surveys')
        .doc(widget.survey.id)
        .collection('questions')
        .get();

    var results = await Future.wait([fetchUserFuture, fetchQuestionsFuture]);

    DocumentSnapshot userDoc = results[0] as DocumentSnapshot;
    QuerySnapshot questionSnapshot = results[1] as QuerySnapshot;

    if (userDoc.exists) {
      widget.participant.name = userDoc['fullName'];
    }

    List<Map<String, dynamic>> questions = questionSnapshot.docs
        .map((doc) => doc.data() as Map<String, dynamic>)
        .toList();

    setState(() {
      questions = questions;
    });
  }

  buildScoreData() {
    final fontSize =
        Provider.of<FontSizeProvider>(context, listen: false).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);
    ScoreData scoreData =
        widget.scoreData; // Calculate the total score and correct answers
    double totalScore = scoreData.totalScore;
    int correctAnswers = scoreData.correctAnswers;

    return Container(
      padding: const EdgeInsets.all(16),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: 'total_score'.tr(),
              style: TextStyle(
                color: _textColor(context),
                fontSize: timeFontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextSpan(
              text: ' ${totalScore.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: timeFontSize,
                fontWeight: FontWeight.bold,
                color: totalScore < 50
                    ? Colors.red
                    : (totalScore < 75 ? Colors.orange : Colors.green),
              ),
            ),
            TextSpan(
              text: '\n${'correct_answers'.tr()} ',
              style: TextStyle(
                color: _textColor(context),
                fontSize: timeFontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextSpan(
              text: '$correctAnswers',
              style: TextStyle(
                fontSize: timeFontSize,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.participant.name}\'s ${'answers'.tr()}'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.participant.surveyAnswers.length,
              itemBuilder: (context, index) {
                String surveyId =
                    widget.participant.surveyAnswers.keys.elementAt(index);
                Map<String, dynamic> questionData =
                    widget.survey.questions[int.parse(surveyId.substring(1))];

                List<dynamic> answers =
                    widget.participant.surveyAnswers[surveyId] ?? [];
                String question = questionData['question'];
                List<String>? options =
                    questionData['options'] as List<String>? ??
                        ['True', 'False'];

                List<dynamic>? correctAnswers =
                    questionData['correctAnswers'] as List<dynamic>?;
                bool isMultiCorrect =
                    correctAnswers != null && correctAnswers.length > 1;

                Widget answerDisplay;
                if (questionData['type'] == 'Text') {
                  bool isAnswerConfirmed =
                      textQuestionCorrect[surveyId] ?? false;

                  answerDisplay = Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    color: isAnswerConfirmed
                        ? Colors.green.withOpacity(0.5)
                        : Colors.red.withOpacity(0.5),
                    child: SingleChildScrollView(
                      child: Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                answers.join(', '),
                                style: const TextStyle(color: Colors.white),
                                overflow: TextOverflow.visible,
                              ),
                            ),
                          ),
                          Column(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.check),
                                color: isAnswerConfirmed
                                    ? Colors.green[800]
                                    : Colors.white,
                                onPressed: () {
                                  setState(() {
                                    textQuestionCorrect[surveyId] = true;
                                  });
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                color: isAnswerConfirmed
                                    ? Colors.white
                                    : Colors.red[800],
                                onPressed: () {
                                  setState(() {
                                    textQuestionCorrect[surveyId] = false;
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                } else {
                  answerDisplay = ListView.builder(
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, optionIndex) {
                      String option = options[optionIndex];
                      bool isSelected = answers.contains(optionIndex);
                      bool isCorrect = answers.isEmpty
                          ? false
                          : isMultiCorrect
                              ? correctAnswers.contains(optionIndex)
                              : (correctAnswers != null &&
                                  correctAnswers.length == 1 &&
                                  correctAnswers[0] == optionIndex);

                      if (isMultiCorrect) {
                        isCorrect = correctAnswers.contains(optionIndex);
                      } else if (!isMultiCorrect &&
                          surveyId.contains(optionIndex.toString())) {
                        isCorrect = true;
                      }

                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        color: isCorrect
                            ? Colors.green.withOpacity(0.5)
                            : isSelected
                                ? Colors.red.withOpacity(0.5)
                                : null,
                        child: Padding(
                          padding: const EdgeInsets.all(13),
                          child: Row(
                            children: [
                              isSelected
                                  ? const Icon(
                                      Icons.check_circle_outline,
                                      color: Colors.white,
                                    )
                                  : const Icon(
                                      Icons.radio_button_unchecked,
                                    ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  option,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : isCorrect
                                            ? Colors.black
                                            : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }

                return Padding(
                  padding: const EdgeInsets.all(16),
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
                      const SizedBox(height: 8),
                      answerDisplay,
                      const SizedBox(height: 16),
                    ],
                  ),
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                child: buildScoreData(),
              ),
              IconButton(
                onPressed: () async {
                  final pdf = await _generatePdf();
                  await Printing.layoutPdf(
                    onLayout: (PdfPageFormat format) async => pdf.save(),
                  );
                },
                icon: const Icon(Icons.print),
              )
            ],
          )
        ],
      ),
    );
  }

  Future<pw.Document> _generatePdf() async {
    var fontSizeProvider =
        Provider.of<FontSizeProvider>(context, listen: false);
    var fontSize = fontSizeProvider.fontSize;

    final timeFontSize = getTimeFontSize(context, fontSize);
    final pdf = pw.Document();
    ScoreData scoreData = widget.scoreData;
    double totalScore = scoreData.totalScore;
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
          questionData['options'] as List<String>? ?? ['True', 'False'];

      List<dynamic>? correctAnswers =
          questionData['correctAnswers'] as List<dynamic>?;
      bool isMultiCorrect = correctAnswers != null && correctAnswers.length > 1;

      pw.Widget answerDisplay;
      if (questionData['type'] == 'Text') {
        bool isAnswerConfirmed = textQuestionCorrect[surveyId] ?? false;
        ScoreData scoreData = widget.scoreData;
        double currentQuestionScore = scoreData.totalScore;
        totalScore += currentQuestionScore;

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

        for (int optionIndex = 0; optionIndex < options.length; optionIndex++) {
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
            optionWidgets.add(pw.SizedBox(height: 16)); // Space between options
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
              width:
                  400, // Set the desired width for the question and answer section
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    constraints: pw.BoxConstraints(
                      minWidth: 400, // Set a smaller width for the list
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
                    '${'total_score'.tr()} ${totalScore.toStringAsFixed(1)}%',
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
}
