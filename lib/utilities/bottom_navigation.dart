import 'package:flutter/material.dart';
import 'package:survey_app_ks/appointment/main_survey/survey_main.dart';
import 'package:survey_app_ks/home.dart';
import 'package:survey_app_ks/settings/settings.dart';
import 'package:survey_app_ks/survey_questionary/main_sruvey/survey_main.dart';

class BottomNavigation extends StatefulWidget {
  final int initialIndex;
  const BottomNavigation({super.key, this.initialIndex = 0});

  @override
  BottomNavigationState createState() => BottomNavigationState();
}

class BottomNavigationState extends State<BottomNavigation> {
  late int _currentIndex;

  final List<Widget> _pages = [
    const TodoList(),
    const SurveyPageUI(),
    const QuestionarySurveyPageUI(),
    const SettingsPageUI(),
  ];

  Color? _textColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF004B96)
        : Colors.white;
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // Fixed type for consistent look
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[900]
            : Colors.grey[300],
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        showSelectedLabels: true, // Always show labels
        showUnselectedLabels: true,
        selectedFontSize: 12, // Adjust font size if necessary
        unselectedFontSize: 12,
        selectedItemColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.tealAccent // Bright color for dark theme
            : Colors.lightBlue, // Saturated color for light theme
        unselectedItemColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[600] // Muted for dark theme
            : Colors.grey[500],
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.notes_outlined),
            label: 'Notes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.schedule_outlined),
            label: 'Appointments',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.quiz_outlined),
            label: 'Survey',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
