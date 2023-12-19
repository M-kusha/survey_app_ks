import 'package:flutter/material.dart';
import 'package:survey_app_ks/appointment/main_survey/survey_main.dart';
import 'package:survey_app_ks/home.dart';
import 'package:survey_app_ks/settings/settings.dart';
import 'package:survey_app_ks/survey_questionary/main_sruvey/survey_main.dart';

class BotomNavigation extends StatefulWidget {
  const BotomNavigation({super.key});

  @override
  BotomNavigationState createState() => BotomNavigationState();
}

class BotomNavigationState extends State<BotomNavigation> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomePage(),
    const SurveyPageUI(),
    const QuestionarySurveyPageUI(),
    const SettingsPageUI(),
  ];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex], // Display the selected page
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped, // Call _onTabTapped when a tab is tapped
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_max_outlined),
            label: 'Home',
            backgroundColor: Colors.blueGrey,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.schedule_outlined),
            label: 'Appointments',
            backgroundColor: Colors.blueGrey,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.quiz_outlined),
            label: 'Favorites',
            backgroundColor: Colors.blueGrey,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
            backgroundColor: Colors.blueGrey,
          ),
        ],
      ),
    );
  }
}
