import 'package:echomeet/survey_pages/admin/survey_analytics.dart';
import 'package:echomeet/survey_pages/admin/survey_participants.dart';
import 'package:echomeet/survey_pages/utilities/survey_data_provider.dart';
import 'package:echomeet/survey_pages/utilities/survey_questionary_class.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AdminOverviewPage extends StatefulWidget {
  final String surveyId;
  final Survey survey;
  final List<Participant> participants;

  const AdminOverviewPage(
      {Key? key,
      required this.surveyId,
      required this.survey,
      required this.participants})
      : super(key: key);

  @override
  AdminOverviewPageState createState() => AdminOverviewPageState();
}

class AdminOverviewPageState extends State<AdminOverviewPage> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SurveyDataProvider>(context, listen: false)
          .loadParticipants(widget.surveyId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildCurrentPage(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.group),
            label: 'Participants',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentPage() {
    final participants =
        Provider.of<SurveyDataProvider>(context).participants ?? [];
    switch (_currentIndex) {
      case 0:
        return SurveyParticipantsPage(
          survey: widget.survey,
          participants: participants,
          surveyId: widget.surveyId,
        );

      case 1:
        return SurveyAnalyticsPage(
          survey: widget.survey,
          participants: participants,
        );
      default:
        return Container();
    }
  }
}
