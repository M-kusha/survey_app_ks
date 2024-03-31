import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/settings/font_size_provider.dart';
import 'package:echomeet/survey_pages/admin/survey_analytics.dart';
import 'package:echomeet/survey_pages/admin/survey_participants.dart';
import 'package:echomeet/survey_pages/user_survey/step1_participate_survey.dart';
import 'package:echomeet/survey_pages/utilities/survey_data_provider.dart';
import 'package:echomeet/survey_pages/utilities/survey_questionary_class.dart';
import 'package:echomeet/utilities/reusable_widgets.dart';
import 'package:echomeet/utilities/text_style.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart';

class SurveyListItem extends StatelessWidget {
  final Survey survey;
  final bool isAdmin;
  final bool hasParticipated;

  const SurveyListItem(
      {super.key,
      required this.survey,
      required this.isAdmin,
      required this.hasParticipated});

  Color? _textColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? const Color(0xFF004B96)
        : Colors.grey[900];
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserDataProvider>(context);
    final userId = userProvider.currentUser?.id ?? "Unknown ID";
    final userName = userProvider.currentUser?.name ?? "Guest";
    final profileImage = userProvider.currentUser?.profileImage ?? '';
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final screenWidth = MediaQuery.of(context).size.width;
    final isExpired = survey.deadline.isBefore(DateTime.now()) ? true : false;
    final timeFontSize = screenWidth < 600
        ? fontSize.clamp(0.0, 15.0)
        : fontSize.clamp(0.0, 30.0);

    return Stack(
      children: [
        GestureDetector(
          onTap: (!isExpired && !hasParticipated)
              ? () => navigateToSurvey(context, userId, userName, profileImage)
              : null,
          child: Opacity(
            opacity: (isExpired || hasParticipated) ? 0.7 : 1.0,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: BorderSide(
                    color: isExpired
                        ? getButtonColor(context).withOpacity(0.5)
                        : getButtonColor(context),
                    width: 2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      builTitle(context, timeFontSize),
                      const SizedBox(height: 8.0),
                      _buildInfoRow(context, timeFontSize, isExpired),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (isAdmin)
          adminButton(
            context,
            getButtonColor(context),
          ),
      ],
    );
  }

  Text builTitle(BuildContext context, double timeFontSize) {
    return Text(
      survey.surveyName,
      style: TextStyle(
        color: Theme.of(context).brightness == Brightness.light
            ? _textColor(context)
            : Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: timeFontSize,
      ),
    );
  }

  Positioned adminButton(BuildContext context, Color buttonColor) {
    return Positioned(
      top: -5,
      right: -8,
      child: IconButton(
        icon: Icon(
          Icons.admin_panel_settings,
          color: buttonColor,
        ),
        onPressed: () async {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return const CustomLoadingWidget(
                loadingText: 'loading',
              );
            },
          );

          final provider =
              Provider.of<SurveyDataProvider>(context, listen: false);
          await provider.loadParticipants(survey.id);

          if (!context.mounted) return;
          Navigator.pop(context);
          navigateToAdminOverview(context);
        },
      ),
    );
  }

  RichText _buildRichText(BuildContext context, double timeFontSize,
      bool isExpired, Color buttonColor) {
    String statusText;
    Color statusColor;

    if (isExpired) {
      statusText = 'expired'.tr();
      statusColor = Colors.red;
    } else if (hasParticipated) {
      statusText = 'already_participated'.tr();
      statusColor = buttonColor;
    } else {
      statusText = 'open'.tr();
      statusColor = buttonColor;
    }

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: survey.surveyType == SurveyType.survey
                ? '${'survey_status'.tr()}: '
                : survey.surveyType == SurveyType.test
                    ? '${'test_status'.tr()}: '
                    : 'Survey: ',
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.light
                  ? _textColor(context)
                  : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: timeFontSize,
            ),
          ),
          TextSpan(
            text: statusText,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
              fontSize: timeFontSize,
            ),
          ),
        ],
      ),
    );
  }

  Row _buildInfoRow(BuildContext context, double timeFontSize, bool isExpired) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildColumnLeft(
            context, timeFontSize, isExpired, getButtonColor(context)),
        _buildColumnRight(context, timeFontSize),
      ],
    );
  }

  Column _buildColumnLeft(BuildContext context, double timeFontSize,
      bool isExpired, Color buttonColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildRichText(
            context, timeFontSize, isExpired, getButtonColor(context)),
        SizedBox(height: timeFontSize),
        Text(
          '${'expires'.tr()} ${DateFormat('EEEE dd MMMM').format(survey.deadline)}',
          style: TextStyle(
            fontSize: timeFontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Column _buildColumnRight(BuildContext context, double timeFontSize) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'ID: ${survey.id}',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.light
                ? _textColor(context)
                : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: timeFontSize,
          ),
        ),
        SizedBox(height: timeFontSize),
        Text(
          format(survey.timeCreated),
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.light
                ? _textColor(context)
                : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: timeFontSize,
          ),
        ),
      ],
    );
  }

  void navigateToAdminOverview(BuildContext context) {
    final participantsData =
        Provider.of<SurveyDataProvider>(context, listen: false).participants;

    if (participantsData != null) {
      if (survey.surveyType == SurveyType.survey) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SurveyAnalyticsPage(
              survey: survey,
              participants: participantsData,
            ),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SurveyParticipantsPage(
              survey: survey,
              participants: participantsData,
              surveyId: survey.id,
            ),
          ),
        );
      }
    }
  }

  void navigateToSurvey(BuildContext context, String userId, String userName,
      String profileImage) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return Step1ParticipateSurvey(
            survey: survey,
            participant: Participant(
              name: userName,
              userId: userId,
              surveyAnswers: {},
              score: 0,
              textAnswersReviewed: {},
            ),
            imageProfile: profileImage,
          );
        },
      ),
    );
  }
}
