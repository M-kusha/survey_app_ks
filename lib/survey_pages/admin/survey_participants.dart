import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/settings/font_size_provider.dart';
import 'package:echomeet/survey_pages/admin/participant_results.dart';
import 'package:echomeet/survey_pages/utilities/survey_data_provider.dart';
import 'package:echomeet/survey_pages/utilities/survey_questionary_class.dart';
import 'package:echomeet/utilities/reusable_widgets.dart';
import 'package:echomeet/utilities/text_style.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SurveyParticipantsPage extends StatefulWidget {
  final List<Participant> participants;
  final Survey survey;
  final String surveyId;

  const SurveyParticipantsPage(
      {Key? key,
      required this.participants,
      required this.survey,
      required this.surveyId})
      : super(key: key);

  @override
  SurveyParticipantsPageState createState() => SurveyParticipantsPageState();
}

class SurveyParticipantsPageState extends State<SurveyParticipantsPage> {
  int selectedSortOption = -1; // Default to showing all participants

  @override
  Widget build(BuildContext context) {
    final buttonColor = Theme.of(context).colorScheme.secondary;
    final listTileColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.survey.surveyName} - ${'panel'.tr()}',
          style: TextStyle(
            fontSize: fontSize * 1.2,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: getAppbarColor(context),
        actions: [buildPopupMenuButton(context, buttonColor, listTileColor)],
        centerTitle: true,
      ),
      body: widget.survey.surveyType == SurveyType.survey
          ? Center(child: Text('this_page_shows'.tr()))
          : _buildParticipantsView(),
    );
  }

  Widget _buildParticipantsView() {
    final participants =
        Provider.of<SurveyDataProvider>(context).participants ?? [];
    if (participants.isEmpty) {
      return Center(child: Text('no_participants_added_yet'.tr()));
    }

    List<Participant> filteredParticipants = _filterParticipants(participants);

    if (filteredParticipants.isEmpty) {
      String message = (selectedSortOption == 0)
          ? 'no_user_found_with_score_50_or_more'.tr()
          : 'no_user_found_with_score_less_than_50'.tr();
      return Center(child: Text(message));
    }

    return ListView.builder(
      itemCount: filteredParticipants.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.all(8.0),
        child: _participantListItem(filteredParticipants[index]),
      ),
    );
  }

  List<Participant> _filterParticipants(List<Participant> participants) {
    switch (selectedSortOption) {
      case -1:
        return participants;
      case 0: // Score >= 50%
        return participants.where((p) => p.score >= 50).toList();
      case 1: // Score < 50%
        return participants.where((p) => p.score < 50).toList();

      default:
        return participants;
    }
  }

  Widget _participantListItem(Participant participant) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    Color scoreColor = _determineScoreColor(participant.score);

    return GestureDetector(
      onTap: () => _navigateToParticipantAnswers(participant),
      child: Card(
        elevation: 4,
        shadowColor: getButtonColor(context),
        child: ListTile(
          leading: CircleAvatar(
            backgroundImage: participant.imageProfile.isNotEmpty
                ? NetworkImage(participant.imageProfile)
                : null,
            child: participant.imageProfile.isEmpty
                ? participant.imageProfile.isNotEmpty
                    ? const CustomLoadingWidget()
                    : Text(
                        participant.name[0],
                        style: TextStyle(fontSize: fontSize),
                      )
                : null,
          ),
          title: Text(participant.name,
              style:
                  TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold)),
          subtitle: Text(
              '${'correct_answers'.tr()} ${participant.totalCorrectAnswers}/ ${widget.survey.questions.length}'),
          trailing: Text('(${participant.score.toStringAsFixed(1)}%)',
              style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: scoreColor)),
        ),
      ),
    );
  }

  Color _determineScoreColor(double score) {
    if (score >= 75) {
      return Colors.green; // High score
    } else if (score >= 50) {
      return Colors.orange; // Medium score
    } else {
      return Colors.red; // Low score
    }
  }

  void _navigateToParticipantAnswers(Participant participant) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ParticipantAnswersPage(
          participant: participant,
          survey: widget.survey,
          totalScore: participant.score,
          userId: participant.userId,
          correctAnswersCount: participant.totalCorrectAnswers,
        ),
      ),
    );
  }

  PopupMenuButton<int> buildPopupMenuButton(
      BuildContext context, Color buttonColor, Color listTileColor) {
    return PopupMenuButton<int>(
      icon: Icon(Icons.sort, color: buttonColor),
      onSelected: (value) => setState(() => selectedSortOption = value),
      itemBuilder: (BuildContext context) => [
        PopupMenuItem(
          value: -1,
          child: Row(
            children: [
              Icon(Icons.people, color: listTileColor),
              const SizedBox(width: 8),
              Text('all_participants'.tr()),
            ],
          ),
        ),
        PopupMenuItem(
          value: 0,
          child: Row(
            children: [
              Icon(Icons.trending_up, color: listTileColor),
              const SizedBox(width: 8),
              Text('50_or_more'.tr()),
            ],
          ),
        ),
        PopupMenuItem(
          value: 1,
          child: Row(
            children: [
              Icon(Icons.trending_down, color: listTileColor),
              const SizedBox(width: 8),
              Text('less_than_50'.tr()),
            ],
          ),
        ),
      ],
    );
  }
}
