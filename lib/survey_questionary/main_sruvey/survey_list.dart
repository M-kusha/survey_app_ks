import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:survey_app_ks/settings/font_size_provider.dart';
import 'package:survey_app_ks/survey_questionary/admin/admin_overview.dart';
import 'package:survey_app_ks/survey_questionary/user_survey/survey_user_page.dart';
import 'package:survey_app_ks/survey_questionary/utilities/survey_questionary_class.dart';
import 'package:survey_app_ks/utilities/tablet_size.dart';
import 'package:timeago/timeago.dart';

enum SortingOption {
  mostParticipants,
  leastParticipants,
  mostRecent,
  expirationDateAscending,
  expirationDateDescending,
}

class SurveyListItem extends StatelessWidget {
  final SurveyQuestionaryType survey;

  const SurveyListItem({Key? key, required this.survey}) : super(key: key);

  Color? _textColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? const Color(0xFF004B96)
        : Colors.grey[900];
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final screenWidth = MediaQuery.of(context).size.width;
    final timeFontSize = screenWidth < 600
        ? (fontSize.clamp(00.0, 15.0))
        : (fontSize.clamp(00.0, 30.0));

    final isExpired = survey.deadline?.isBefore(DateTime.now()) ?? false;
    return GestureDetector(
      onTap: isExpired
          ? null
          : () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) {
                    return QuestionaryTrainingUser(
                      survey: survey,
                      participant: Participant(
                        name: '',
                        id: '',
                        surveyAnswers: {},
                        score: 0,
                        correctAnswers: 0,
                      ),
                    );
                  },
                ),
              );
            },
      child: Stack(
        children: [
          Positioned(
            top: -10, // Adjust the position according to your requirements
            right: -7, // Adjust the position according to your requirements
            child: IconButton(
              icon: Icon(
                Icons.admin_panel_settings,
                color: Theme.of(context).brightness == Brightness.light
                    ? _textColor(context)
                    : Colors.white,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AdminOverviewPage(survey: survey, surveyId: survey.id),
                  ),
                );
              },
            ),
          ),
          Opacity(
            opacity: isExpired ? 0.5 : 1.0,
            child: Container(
              padding: EdgeInsets.all(timeFontSize * 1.5),
              margin: EdgeInsets.symmetric(
                  vertical: timeFontSize, horizontal: timeFontSize * 1.5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12.0),
                color: Theme.of(context).brightness == Brightness.light
                    ? Colors.grey[200]
                    : Colors.grey[900],
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    spreadRadius: 0,
                    blurRadius: 4,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    '${'survey_status'.tr()}: ${isExpired ? 'expired'.tr() : 'open'.tr()}',
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.light
                          ? _textColor(context)
                          : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: timeFontSize,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            survey.surveyName,
                            style: TextStyle(
                              color: Theme.of(context).brightness ==
                                      Brightness.light
                                  ? _textColor(context)
                                  : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: timeFontSize,
                            ),
                          ),
                          SizedBox(height: timeFontSize),
                          Text(
                              'Expires: ${DateFormat('dd E y').format(survey.deadline ?? DateTime.now())}',
                              style: TextStyle(
                                fontSize: timeFontSize,
                                fontWeight: FontWeight.bold,
                              )),
                        ],
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'ID: ${survey.id}',
                            style: TextStyle(
                              color: Theme.of(context).brightness ==
                                      Brightness.light
                                  ? _textColor(context)
                                  : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: timeFontSize,
                            ),
                          ),
                          SizedBox(height: timeFontSize),
                          Text(
                            ' ${format(survey.timeCreated)}',
                            style: TextStyle(
                              color: Theme.of(context).brightness ==
                                      Brightness.light
                                  ? _textColor(context)
                                  : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: timeFontSize,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget buildExpandedField(BuildContext context, bool isSearching,
    String searchQuery, SortingOption selectedOption) {
  final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
  final timeFontSize = getTimeFontSize(context, fontSize);

  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance.collection('questionary').snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(child: Text('Error: ${snapshot.error}'));
      }
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }

      List<SurveyQuestionaryType> surveyList = snapshot.data!.docs
          .map((doc) => SurveyQuestionaryType.fromFirestore(
              doc.data() as Map<String, dynamic>))
          .toList();

      // Apply the search query if needed
      if (isSearching) {
        surveyList = surveyList
            .where((survey) =>
                survey.surveyName
                    .toLowerCase()
                    .contains(searchQuery.toLowerCase()) ||
                survey.surveyDescription
                    .toLowerCase()
                    .contains(searchQuery.toLowerCase()))
            .toList();
      }
      sortSurveys(surveyList, selectedOption);
      if (surveyList.isEmpty) {
        return Expanded(
          child: Center(
              child: Text('No surveys found',
                  style: TextStyle(fontSize: timeFontSize * 1.2))),
        );
      }

      return Expanded(
        child: ListView.builder(
          itemCount: surveyList.length,
          itemBuilder: (context, index) {
            return SurveyListItem(
                survey: surveyList[
                    index]); // Ensure you have a SurveyListItem widget
          },
        ),
      );
    },
  );
}

void sortSurveys(List<SurveyQuestionaryType> surveys, SortingOption option) {
  switch (option) {
    case SortingOption.mostParticipants:
      surveys.sort(
          (a, b) => b.participants.length.compareTo(a.participants.length));
      break;
    case SortingOption.leastParticipants:
      surveys.sort(
          (a, b) => a.participants.length.compareTo(b.participants.length));
      break;
    case SortingOption.mostRecent:
      surveys.sort((a, b) => b.timeCreated.compareTo(a.timeCreated));
      break;
    case SortingOption.expirationDateAscending:
      surveys.sort((a, b) => a.deadline!.compareTo(b.deadline!));
      break;
    case SortingOption.expirationDateDescending:
      surveys.sort((a, b) => b.deadline!.compareTo(a.deadline!));
      break;
  }
}
