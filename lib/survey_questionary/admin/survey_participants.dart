import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:survey_app_ks/settings/font_size_provider.dart';
import 'package:survey_app_ks/survey_questionary/admin/participant_results.dart';
import 'package:survey_app_ks/survey_questionary/utilities/survey_questionary_class.dart';
import 'package:survey_app_ks/utilities/tablet_size.dart';

class ScoreData {
  final double totalScore;
  final int correctAnswers;

  ScoreData(this.totalScore, this.correctAnswers);
}

class SurveyParticipantsPage extends StatefulWidget {
  final SurveyQuestionaryType survey;

  const SurveyParticipantsPage({
    Key? key,
    required this.survey,
  }) : super(key: key);

  @override
  SurveyParticipantsPageState createState() => SurveyParticipantsPageState();
}

class SurveyParticipantsPageState extends State<SurveyParticipantsPage> {
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
    _fetchParticipants();
    if (participants.isNotEmpty) {
      calculateTotalScoreAndCorrectAnswers(participants[0]);
    }
  }

  void _fetchParticipants() async {
    try {
      String surveyId = widget.survey.id;
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('surveyAnswers')
          .where('surveyId', isEqualTo: surveyId)
          .get();

      List<Participant> fetchedParticipants = [];
      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        if (!data.containsKey('userId')) {
          continue;
        }

        String userId = data['userId'];
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        if (!userDoc.exists) {
          continue;
        }

        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

        fetchedParticipants.add(
          Participant(
            id: userId,
            name: userData['fullName'] ?? 'Unknown', // Accessing fullName field
            surveyAnswers: data['surveyAnswers'] ?? {},
            correctAnswers: data['correctAnswers'] ?? 0,
            score: (data['score'] ?? 0.0).toDouble(),
          ),
        );
      }

      setState(() {
        participants = fetchedParticipants;
      });
    } catch (e) {}
  }

  Map<String, dynamic> calculateTotalScoreAndCorrectAnswers(
      Participant participant) {
    int numQuestions = widget.survey.questions.length;
    int correctAnswers = widget.survey.correctAnswers.length;
    int validQuestions = 0;

    for (int index = 0; index < numQuestions; index++) {
      String surveyId = 'Q$index';
      List<dynamic> answers = participant.surveyAnswers[surveyId] ?? [];
      Map<String, dynamic> questionData = widget.survey.questions[index];

      if (questionData['type'] == 'Text') {
        if (textQuestionCorrect[surveyId] ?? false) {
          correctAnswers++;
        }
        validQuestions++;
        continue;
      }

      validQuestions++;

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

    double totalScore = (correctAnswers / validQuestions) * 100;

    return {
      'totalScore': totalScore,
      'correctAnswers': correctAnswers,
    };
  }

  Widget _buildStatisticsWidget(List<Participant> participants) {
    print('Participants: $participants');
    print('correctAnswers: ${widget.survey.correctAnswers}');
    print('questions: ${widget.survey.questions}');
    print('score: ${participants[0].score}');
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            tr(' ${'results_off'.tr()} ${participants.length} ${'participants'.tr()}'),
            style: TextStyle(
              fontSize: timeFontSize,
              color: _textColor(context),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
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
                            style: TextStyle(fontSize: timeFontSize),
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
                                  style: TextStyle(
                                      fontSize: timeFontSize,
                                      fontWeight: FontWeight.bold),
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
    if (participants.isEmpty) {
      return Center(
        child: Text('no_participants_added_yet'.tr()),
      );
    }
    return FutureBuilder(
      future: Future.delayed(const Duration(milliseconds: 300)),
      builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return _buildStatisticsWidget(participants);
        } else {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
      },
    );
  }
}
