import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:survey_app_ks/appointment/survey_class.dart';
import 'package:survey_app_ks/appointment/user_survey/user_survey_buttons.dart';
import 'package:survey_app_ks/appointment/user_survey/user_survey_step_1.dart';
import 'package:survey_app_ks/settings/font_size_provider.dart';
import 'package:survey_app_ks/utilities/tablet_size.dart';

class SurveyListItem extends StatelessWidget {
  final Survey survey;

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

    final nameCount = survey.participants
        .where((participant) =>
            participant.timeSlot.expirationDate.isAfter(DateTime.now()))
        .map((participant) => participant.userName)
        .toSet()
        .length;

    final isExpired = survey.expirationDate.isBefore(DateTime.now());
    return GestureDetector(
      onTap: isExpired
          ? null
          : () {
              final isTimeSlotConfirmed =
                  survey.disableIfYouParticipated == true;
              if (isTimeSlotConfirmed) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) {
                      return SurveyUserSelectCategories(
                          survey: survey,
                          userName: '',
                          timeSlot: TimeSlot(
                            start: DateTime.now(),
                            end: DateTime.now(),
                            expirationDate: DateTime.now(),
                          ));
                    },
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) {
                      return SurveyNamePage(
                          survey: survey,
                          participant: Participant(
                            userName: '',
                            status: '',
                            date: DateTime.now(),
                            timeSlot: TimeSlot(
                              start: DateTime.now(),
                              end: DateTime.now(),
                              expirationDate: DateTime.now(),
                            ),
                          ));
                    },
                  ),
                );
              }
            },
      child: Opacity(
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
                        survey.title,
                        style: TextStyle(
                          color:
                              Theme.of(context).brightness == Brightness.light
                                  ? _textColor(context)
                                  : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: timeFontSize,
                        ),
                      ),
                      SizedBox(height: timeFontSize),
                      Text(
                          '${'voting_expiration_date'.tr()}: ${DateFormat("dd E y").format(survey.expirationDate)}',
                          style: TextStyle(
                            fontSize: timeFontSize,
                            fontWeight: FontWeight.bold,
                          )),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ID: ${survey.id}',
                        style: TextStyle(
                          color:
                              Theme.of(context).brightness == Brightness.light
                                  ? _textColor(context)
                                  : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: timeFontSize,
                        ),
                      ),
                      SizedBox(height: timeFontSize),
                      Text('${'participants'.tr()}: ${nameCount.toString()}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: timeFontSize,
                          )),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget buildExpandedField(
  BuildContext context,
  bool isSearching,
  String searchQuery,
) {
  final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
  final timeFontSize = getTimeFontSize(context, fontSize);

  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance.collection('surveys').snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(child: Text('Error: ${snapshot.error}'));
      }

      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }

      List<Survey> surveyList =
          snapshot.data!.docs.map((DocumentSnapshot document) {
        Map<String, dynamic> data = document.data()! as Map<String, dynamic>;
        return Survey.fromFirestore(data);
      }).toList();

      final filteredSurveys = surveyList
          .where((survey) =>
              survey.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
              survey.id.toLowerCase().contains(searchQuery.toLowerCase()))
          .toList();

      if (filteredSurveys.isEmpty && !isSearching && searchQuery.isEmpty) {
        return Expanded(
          child: Center(
            child: Text(
              'no_surveys_added_yet'.tr(),
              style: TextStyle(fontSize: timeFontSize * 1.2),
            ),
          ),
        );
      } else if (filteredSurveys.isEmpty && isSearching) {
        return Expanded(
          child: Center(
            child: Text(
              'no_matching_surveys'.tr(),
              style: TextStyle(fontSize: timeFontSize * 1.2),
            ),
          ),
        );
      }

      return Expanded(
        child: ListView.separated(
          separatorBuilder: (context, index) => const SizedBox(height: 20.0),
          itemCount: filteredSurveys.length,
          itemBuilder: (context, index) {
            return SurveyListItem(
              survey: filteredSurveys[index],
            );
          },
        ),
      );
    },
  );
}
