import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:survey_app_ks/settings/font_size_provider.dart';
import 'package:survey_app_ks/survey_pages/admin/print_pages/print_results.dart';
import 'package:survey_app_ks/survey_pages/utilities/firebase_survey_service.dart';
import 'package:survey_app_ks/survey_pages/utilities/survey_questionary_class.dart';
import 'package:survey_app_ks/utilities/text_style.dart';

class ParticipantAnswersPage extends StatefulWidget {
  final Participant participant;
  final Survey survey;
  final int correctAnswersCount;
  final double totalScore;
  final String userId;

  const ParticipantAnswersPage({
    Key? key,
    required this.participant,
    required this.survey,
    required this.correctAnswersCount,
    required this.totalScore,
    required this.userId,
  }) : super(key: key);

  @override
  ParticipantAnswersPageState createState() => ParticipantAnswersPageState();
}

class ParticipantAnswersPageState extends State<ParticipantAnswersPage> {
  Map<String, bool> textQuestionCorrect = {};
  Map<String, dynamic> textQuestionStatus = {};
  FirebaseSurveyService firebaseSurveyService = FirebaseSurveyService();
  void confirmCorrectAnswer(String surveyId, String questionId,
      String participantId, bool isCorrect) async {
    String uniqueQuestionKey = '$surveyId-$questionId';

    final newTextAnswersReviewed =
        Map<String, bool>.from(widget.participant.textAnswersReviewed)
          ..[uniqueQuestionKey] = isCorrect;
    final totalQuestions = widget.survey.questions.length;
    final valuePerQuestion = 100 / totalQuestions;
    final newCorrectAnswersCount = isCorrect
        ? widget.participant.totalCorrectAnswers + 1
        : widget.participant.totalCorrectAnswers;
    final newScore = isCorrect
        ? widget.participant.score + valuePerQuestion
        : widget.participant.score;

    setState(() {
      widget.participant.totalCorrectAnswers = newCorrectAnswersCount;
      widget.participant.score = newScore;
      widget.participant.textAnswersReviewed = newTextAnswersReviewed;
    });

    await firebaseSurveyService.updateTextAnswersReviewed(
        surveyId, participantId, newTextAnswersReviewed);
    await firebaseSurveyService.updateScore(surveyId, participantId, newScore);
    await firebaseSurveyService.updateCorrectAnswersCount(
        surveyId, participantId, newCorrectAnswersCount);
  }

  @override
  Widget build(BuildContext context) {
    List<MapEntry<String, dynamic>> nonTextQuestions = [];
    List<MapEntry<String, dynamic>> textQuestions = [];
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;

    for (var entry in widget.participant.surveyAnswers.entries) {
      Map<String, dynamic> questionData =
          widget.survey.questions[int.parse(entry.key.substring(1))];
      if (questionData['type'] == 'Text') {
        textQuestions.add(entry);
      } else {
        nonTextQuestions.add(entry);
      }
    }

    List<MapEntry<String, dynamic>> sortedQuestions =
        nonTextQuestions + textQuestions;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.participant.name}\'s ${'answers'.tr()},',
          style: TextStyle(
            fontSize: fontSize * 1.2,
            fontWeight: FontWeight.bold,
            color: _textColor(context),
          ),
        ),
        backgroundColor: getAppbarColor(context),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: sortedQuestions.length,
              itemBuilder: (context, index) {
                String surveyId = sortedQuestions[index].key;
                Map<String, dynamic> questionData =
                    widget.survey.questions[int.parse(surveyId.substring(1))];

                return buildQuestionCard(questionData, surveyId, fontSize);
              },
            ),
          ),
          buildScoreRow(),
        ],
      ),
    );
  }

  Widget buildQuestionCard(
    Map<String, dynamic> questionData,
    String surveyId,
    final fontSize,
  ) {
    List<dynamic> answers = widget.participant.surveyAnswers[surveyId] ?? [];
    String question = questionData['question'];
    List<String> options = (questionData['options'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        ['True', 'False'];
    Widget answerDisplay;
    if (questionData['type'] == 'Text') {
      answerDisplay = buildTextAnswerDisplay(
          questionData, surveyId, answers, widget.participant.userId, fontSize);
    } else {
      answerDisplay = buildOptionsAnswerDisplay(options, answers, questionData);
    }
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        shadowColor: getButtonColor(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              constraints: BoxConstraints(
                minWidth: double.infinity,
                minHeight: getTimeFontSize(context,
                        Provider.of<FontSizeProvider>(context).fontSize) *
                    3,
              ),
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Text(
                  question,
                  style: TextStyle(
                    fontSize: getTimeFontSize(context,
                        Provider.of<FontSizeProvider>(context).fontSize),
                    fontWeight: FontWeight.bold,
                    color: _textColor(context),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            answerDisplay,
          ],
        ),
      ),
    );
  }

  Widget buildTextAnswerDisplay(
    Map<String, dynamic> questionData,
    String questionId,
    List<dynamic> answers,
    String participantId,
    final fontSize,
  ) {
    String uniqueQuestionKey = "${widget.survey.id}-$questionId";

    bool isReviewed =
        widget.participant.textAnswersReviewed[uniqueQuestionKey] ?? false;

    Color bgColor = isReviewed ? Colors.green[300]! : Colors.red[100]!;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        shadowColor: getButtonColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        color: bgColor,
        child: ListTile(
          title: Text(answers.join(', '),
              style: TextStyle(color: Colors.black, fontSize: fontSize)),
          trailing: isReviewed
              ? Icon(Icons.check, color: getCardColor(context))
              : IconButton(
                  icon: const Icon(Icons.check, color: Colors.grey),
                  onPressed: () => confirmCorrectAnswer(
                      widget.survey.id, questionId, participantId, true),
                ),
        ),
      ),
    );
  }

  Widget buildOptionsAnswerDisplay(List<String> options, List<dynamic> answers,
      Map<String, dynamic> questionData) {
    bool isSingleChoice = questionData['type'] == "Single";

    List<dynamic>? correctAnswers;
    int? singleCorrectAnswer;

    if (isSingleChoice) {
      singleCorrectAnswer = questionData['correctAnswer'];
    } else {
      correctAnswers = questionData['correctAnswers'] as List<dynamic>?;
    }

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: options.length,
      itemBuilder: (context, optionIndex) {
        String option = options[optionIndex];
        bool isSelected = answers.contains(optionIndex);
        bool isCorrect;

        if (isSingleChoice) {
          isCorrect = optionIndex == singleCorrectAnswer;
        } else {
          isCorrect =
              correctAnswers != null && correctAnswers.contains(optionIndex);
        }

        Widget leadingIcon =
            Icon(Icons.radio_button_unchecked, color: getCardColor(context));
        Color bgColor = Colors.grey[200]!;

        if (isSelected) {
          if (isCorrect) {
            // Option is selected and correct
            leadingIcon = Icon(Icons.check, color: getCardColor(context));
            bgColor = Colors.green[300]!;
          } else {
            // Option is selected and incorrect
            leadingIcon = const Icon(Icons.close, color: Colors.red);
            bgColor = Colors.red[100]!;
          }
        } else if (isCorrect) {
          leadingIcon = Icon(Icons.check, color: getCardColor(context));
          bgColor = Colors.green[300]!;
        }

        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            color: bgColor,
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Row(
                children: [
                  leadingIcon,
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      option,
                      style: TextStyle(color: getCardColor(context)),
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.person, color: getCardColor(context))
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget buildScoreRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: buildScoreData(),
        ),
        IconButton(
          onPressed: () async {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => PDFResults(
                  participant: widget.participant,
                  survey: widget.survey,
                  textQuestionCorrect: textQuestionCorrect,
                ),
              ),
            );
          },
          icon: const Icon(Icons.print),
        )
      ],
    );
  }

  Widget buildScoreData() {
    final fontSize =
        Provider.of<FontSizeProvider>(context, listen: false).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);

    TextSpan buildTextSpan(String text, {Color? color, bool isBold = false}) {
      return TextSpan(
        text: text,
        style: TextStyle(
          color: color ?? _textColor(context),
          fontSize: timeFontSize,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: RichText(
        text: TextSpan(
          children: [
            buildTextSpan('total_score'.tr(), isBold: true),
            buildTextSpan(
              ' ${widget.participant.score.toStringAsFixed(1)}%',
              color: widget.totalScore < 50
                  ? Colors.red
                  : (widget.totalScore < 75 ? Colors.orange : Colors.green),
              isBold: true,
            ),
            buildTextSpan('\n${'correct_answers'.tr()} ', isBold: true),
            buildTextSpan(
              '${widget.participant.totalCorrectAnswers} / ${widget.survey.questions.length}',
              color: Colors.green,
              isBold: true,
            ),
          ],
        ),
      ),
    );
  }

  Color? _textColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? const Color(0xFF004B96)
        : Colors.white;
  }

  double getTimeFontSize(BuildContext context, double fontSize) {
    return fontSize;
  }
}
