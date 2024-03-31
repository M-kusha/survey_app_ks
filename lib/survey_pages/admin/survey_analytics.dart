import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/settings/font_size_provider.dart';
import 'package:echomeet/survey_pages/admin/print_pages/print_analytics.dart';
import 'package:echomeet/survey_pages/utilities/survey_questionary_class.dart';
import 'package:echomeet/utilities/text_style.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SurveyAnalyticsPage extends StatefulWidget {
  final List<Participant> participants;
  final Survey survey;

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

  void _calculateAnswerCounts() {
    if (widget.survey.surveyType != SurveyType.survey) {
      return;
    }

    _answerCounts = List.generate(
      widget.survey.questions.length,
      (index) {
        Map<String, dynamic> questionData = widget.survey.questions[index];

        return List.generate(
          questionData['options'].length,
          (index) => 0,
        );
      },
    );

    for (var participant in widget.participants) {
      participant.surveyAnswers.forEach((surveyId, answers) {
        int questionIndex = int.parse(surveyId.substring(1));
        if (questionIndex >= 0 && questionIndex < _answerCounts.length) {
          for (var answerIndex in answers) {
            if (answerIndex >= 0 &&
                answerIndex < _answerCounts[questionIndex].length) {
              _answerCounts[questionIndex][answerIndex]++;
            }
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.survey.surveyName} - ${'analytics_off'.tr()}',
          style: TextStyle(
            fontSize: fontSize * 1.2,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          child: Column(
            children: [
              if (widget.participants.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20.0, left: 5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${'number_of_participants'.tr()} ${widget.participants.length}',
                        style: TextStyle(
                          fontSize: fontSize * 1.2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () async {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => PDFAnalytics(
                                survey: widget.survey,
                                participants: widget.participants,
                                answerCounts: _answerCounts,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.print),
                      ),
                    ],
                  ),
                ),
              widget.participants.isEmpty
                  ? Center(child: Text('no_participants_added_yet'.tr()))
                  : _buildQuestionsList(context, fontSize),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionsList(BuildContext context, double fontSize) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.survey.questions.length,
      itemBuilder: (context, questionIndex) {
        Map<String, dynamic> questionData =
            widget.survey.questions[questionIndex];

        return _buildQuestionCard(
            context, questionData, questionIndex, fontSize);
      },
    );
  }

  Widget _buildQuestionCard(BuildContext context,
      Map<String, dynamic> questionData, int questionIndex, double fontSize) {
    String question = questionData['question'];
    List<dynamic> options = questionData['options'];

    int totalVotesForQuestion =
        _answerCounts[questionIndex].reduce((a, b) => a + b);

    return Card(
      elevation: 4.0,
      shadowColor: getButtonColor(context),
      margin: const EdgeInsets.only(bottom: 20.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                question,
                style: TextStyle(
                  fontSize: fontSize * 1.1,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),
            ...List<Widget>.generate(options.length, (optionIndex) {
              return _buildOptionRow(context, questionIndex, optionIndex,
                  fontSize, totalVotesForQuestion);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionRow(BuildContext context, int questionIndex,
      int optionIndex, double fontSize, int totalVotesForQuestion) {
    String option =
        widget.survey.questions[questionIndex]['options'][optionIndex];
    int voteCount = _answerCounts[questionIndex][optionIndex];
    double percentage = totalVotesForQuestion > 0
        ? (voteCount / totalVotesForQuestion * 100)
        : 0;
    Color barColor = _dynamicColorBasedOnPercentage(context, percentage);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row(
          //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
          //   children: [
          //     Text(
          //       option,
          //       style: TextStyle(
          //         fontSize: fontSize,
          //         fontWeight: FontWeight.w500,
          //       ),
          //     ),
          //     Text("($voteCount ${'votes'.tr()})",
          //         style: TextStyle(fontSize: fontSize)),
          //   ],
          // ),
          // Row(
          //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
          //   children: [
          //     Expanded(
          //       // This makes the text widget flexible, allowing it to fill available space
          //       child: Text(
          //         option,
          //         overflow: TextOverflow
          //             .ellipsis, // Adds ellipses when text overflows
          //         style: TextStyle(
          //           fontSize: fontSize,
          //           fontWeight: FontWeight.w500,
          //         ),
          //       ),
          //     ),
          //     Text(
          //       "($voteCount ${'votes'.tr()})",
          //       style: TextStyle(fontSize: fontSize),
          //     ),
          //   ],
          // ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option,
                      softWrap: true,
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                "($voteCount ${'votes'.tr()})",
                style: TextStyle(fontSize: fontSize),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: percentage / 100,
              minHeight: 14,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${percentage.toStringAsFixed(1)}%',
            style: TextStyle(
                fontSize: fontSize * 0.75,
                color: barColor,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Color _dynamicColorBasedOnPercentage(
      BuildContext context, double percentage) {
    if (percentage >= 75) {
      return Colors.green;
    } else if (percentage >= 50) {
      return Colors.blueGrey;
    } else if (percentage >= 25) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}
