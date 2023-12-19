import 'package:flutter/material.dart';
import 'package:survey_app_ks/survey_questionary/admin/survey_analytics.dart';
import 'package:survey_app_ks/survey_questionary/admin/survey_participants.dart';
import 'package:survey_app_ks/survey_questionary/admin/survey_statistics.dart';
import 'package:survey_app_ks/survey_questionary/utilities/survey_questionary_class.dart';

class AdminOverviewPage extends StatefulWidget {
  final String surveyId;

  const AdminOverviewPage(
      {Key? key, required this.surveyId, required SurveyQuestionaryType survey})
      : super(key: key);

  @override
  AdminOverviewPageState createState() => AdminOverviewPageState();
}

class AdminOverviewPageState extends State<AdminOverviewPage> {
  int _currentIndex = 0;
  late SurveyQuestionaryType survey;

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchSurvey(widget.surveyId).then((fetchedSurvey) {
      setState(() {
        survey = fetchedSurvey;
        isLoading = false;
      });
    }).catchError((error) {
      // Handle the error
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${survey.surveyName} - admin'),
        centerTitle: true,
      ),
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
            icon: Icon(Icons.insert_chart),
            label: 'Statistics',
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
    switch (_currentIndex) {
      case 0:
        return SurveyParticipantsPage(survey: survey);
      case 1:
        return SurveyStatisticPage(
          survey: survey,
          participants: const [],
        );
      case 2:
        return SurveyAnalyticsPage(
          survey: survey,
          participants: const [],
        );
      default:
        return Container();
    }
  }
}
