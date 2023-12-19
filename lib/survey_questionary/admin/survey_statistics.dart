import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:survey_app_ks/settings/font_size_provider.dart';
import 'package:survey_app_ks/survey_questionary/admin/participant_results.dart';
import 'package:survey_app_ks/survey_questionary/admin/survey_participants.dart';
import 'package:survey_app_ks/survey_questionary/utilities/survey_questionary_class.dart';
import 'package:survey_app_ks/utilities/tablet_size.dart';

class SurveyStatisticPage extends StatefulWidget {
  final List<Participant> participants;
  final SurveyQuestionaryType survey;

  const SurveyStatisticPage({
    Key? key,
    required this.participants,
    required this.survey,
  }) : super(key: key);

  @override
  SurveyStatisticPageState createState() => SurveyStatisticPageState();
}

class SurveyStatisticPageState extends State<SurveyStatisticPage> {
  Color? _textColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? const Color(0xFF004B96)
        : Colors.white;
  }

  int _currentIndex = 0;
  @override
  void initState() {
    super.initState();
    if (widget.survey.participants.isNotEmpty) {
      calculateTotalScoreAndCorrectAnswers(widget.survey.participants[0]);
    }
  }

  Map<String, dynamic> calculateTotalScoreAndCorrectAnswers(
      Participant participant) {
    int numQuestions = widget.survey.questions.length;
    int correctAnswers = 0;

    for (int index = 0; index < numQuestions; index++) {
      String surveyId = 'Q$index';
      List<dynamic> answers = participant.surveyAnswers[surveyId] ?? [];
      Map<String, dynamic> questionData = widget.survey.questions[index];

      if (questionData['type'] == 'text') {
        continue;
      }

      List<dynamic>? correctAnswersList =
          questionData['correctAnswers'] as List<dynamic>?;

      if (correctAnswersList == null) {
        int correctAnswer = questionData['correctAnswer'] != null &&
                questionData['correctAnswer'] is int
            ? questionData['correctAnswer']
            : -1;

        if (answers.contains(correctAnswer)) {
          correctAnswers++;
        }
      } else {
        bool allCorrect = true;
        for (int answer in answers) {
          if (!correctAnswersList.contains(answer)) {
            allCorrect = false;
            break;
          }
        }
        if (allCorrect) {
          correctAnswers++;
        }
      }
    }

    double totalScore = (correctAnswers / numQuestions) * 100;

    return {
      'totalScore': totalScore,
      'correctAnswers': correctAnswers,
    };
  }

  Widget _buildStatisticsWidget(List<Participant> participants) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);
    List<Participant> participantsLessThan50 = [];
    List<Participant> participantsMoreThan50 = [];

    for (Participant participant in participants) {
      Map<String, dynamic> scoreData =
          calculateTotalScoreAndCorrectAnswers(participant);
      double totalScore = scoreData['totalScore'];

      if (totalScore >= 50) {
        participantsMoreThan50.add(participant);
      } else {
        participantsLessThan50.add(participant);
      }
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: _currentIndex == 0
              ? _buildParticipantList(
                  participantsMoreThan50, "more_than_50".tr())
              : _buildParticipantList(
                  participantsLessThan50, "less_than_50".tr()),
        ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _currentIndex = 0;
                  });
                },
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'more_than_50'.tr(),
                  style: TextStyle(fontSize: timeFontSize),
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _currentIndex = 1;
                  });
                },
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  'less_than_50'.tr(),
                  style: TextStyle(fontSize: timeFontSize),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildParticipantList(List<Participant> participants, String type) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            "$type :  ${participants.length} ${'participants'.tr()}",
            style: TextStyle(
                fontSize: timeFontSize,
                fontWeight: FontWeight.bold,
                color: _textColor(context)),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: participants.length,
            itemBuilder: (context, index) {
              Participant participant = participants[index];
              Map<String, dynamic> scoreData =
                  calculateTotalScoreAndCorrectAnswers(participant);
              double totalScore = scoreData['totalScore'];
              int correctAnswers = scoreData['correctAnswers'];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ParticipantAnswersPage(
                        participant: participant,
                        survey: widget.survey,
                        scoreData: ScoreData(totalScore, correctAnswers),
                      ),
                    ),
                  );
                },
                child: Card(
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: CircleAvatar(
                          child: Text(
                            participant.name[0],
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              participant.name,
                              style: TextStyle(
                                fontSize: timeFontSize,
                                color: _textColor(context),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${'correct_answers'.tr()} $correctAnswers / ${widget.survey.questions.length}',
                                  style: TextStyle(fontSize: timeFontSize),
                                ),
                                Text(
                                  ' (${totalScore.toStringAsFixed(1)}%)',
                                  style: TextStyle(
                                    fontSize: timeFontSize,
                                    fontWeight: FontWeight.bold,
                                    color: totalScore < 50
                                        ? Colors.red
                                        : (totalScore < 75
                                            ? Colors.orange
                                            : Colors.green),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.participants.isEmpty) {
      return Center(
        child: Text('no_participants_added_yet'.tr()),
      );
    }
    return FutureBuilder(
      future: Future.delayed(const Duration(milliseconds: 300)),
      builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return _buildStatisticsWidget(widget.participants);
        } else {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
      },
    );
  }
}

class Printing {}
