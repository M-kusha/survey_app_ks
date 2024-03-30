import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/appointments/main_screen/appointments_dashboard.dart';
import 'package:echomeet/notes/notes_main.dart';
import 'package:echomeet/settings/settings.dart';
import 'package:echomeet/survey_pages/main_sruvey/survey_main.dart';
import 'package:echomeet/utilities/text_style.dart';
import 'package:flutter/material.dart';

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
    const AppointmentPageUI(),
    const QuestionarySurveyPageUI(),
    const SettingsPageUI(),
  ];

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
        selectedItemColor:
            getButtonColor(context), // Saturated color for light theme
        unselectedItemColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[600] // Muted for dark theme
            : Colors.grey[500],
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.notes_outlined),
            label: 'notes'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.schedule_outlined),
            label: 'appointments'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.quiz_outlined),
            label: 'survey'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings_outlined),
            label: 'settings'.tr(),
          ),
        ],
      ),
    );
  }
}
