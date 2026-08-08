import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/appointments/main_screen/appointments_dashboard.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/notes/notes_main.dart';
import 'package:echomeet/settings/settings.dart';
import 'package:echomeet/survey_pages/main_sruvey/survey_main.dart';
import 'package:echomeet/utilities/text_style.dart';
import 'package:flutter/material.dart';

/// A navigation destination, described once and rendered by whichever control
/// suits the current window size.
class _Destination {
  const _Destination(this.icon, this.selectedIcon, this.labelKey);

  final IconData icon;
  final IconData selectedIcon;
  final String labelKey;
}

const _destinations = <_Destination>[
  _Destination(Icons.notes_outlined, Icons.notes, 'notes'),
  _Destination(Icons.schedule_outlined, Icons.schedule, 'appointments'),
  _Destination(Icons.quiz_outlined, Icons.quiz, 'survey'),
  _Destination(Icons.settings_outlined, Icons.settings, 'settings'),
];

/// Root shell. Shows a bottom bar on phones and a navigation rail on anything
/// wider, with labels on the rail once there is room for them.
class BottomNavigation extends StatefulWidget {
  const BottomNavigation({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<BottomNavigation> createState() => _BottomNavigationState();
}

class _BottomNavigationState extends State<BottomNavigation> {
  late int _currentIndex = widget.initialIndex;

  // Built once and kept alive by the IndexedStack below. Swapping the child
  // widget on every tab change, as this used to, disposed the other tabs'
  // State — so notes scroll position, filters and search were wiped every time
  // you left the tab and came back.
  static const _pages = <Widget>[
    TodoList(),
    AppointmentPageUI(),
    QuestionarySurveyPageUI(),
    SettingsPageUI(),
  ];

  void _onDestinationSelected(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final windowSize = context.windowSize;
    final body = IndexedStack(index: _currentIndex, children: _pages);

    if (windowSize.usesBottomNavigation) {
      return Scaffold(
        body: body,
        bottomNavigationBar: _buildBottomBar(context),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          _buildRail(context, extended: windowSize.usesExtendedRail),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[300],
      currentIndex: _currentIndex,
      onTap: _onDestinationSelected,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      selectedFontSize: 12,
      unselectedFontSize: 12,
      selectedItemColor: getButtonColor(context),
      unselectedItemColor: isDark ? Colors.grey[600] : Colors.grey[500],
      items: [
        for (final destination in _destinations)
          BottomNavigationBarItem(
            icon: Icon(destination.icon),
            activeIcon: Icon(destination.selectedIcon),
            label: destination.labelKey.tr(),
          ),
      ],
    );
  }

  Widget _buildRail(BuildContext context, {required bool extended}) {
    return SafeArea(
      child: NavigationRail(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onDestinationSelected,
        extended: extended,
        // Labels are redundant next to an extended rail, which already shows
        // them inline.
        labelType: extended
            ? NavigationRailLabelType.none
            : NavigationRailLabelType.all,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        indicatorColor: getButtonColor(context).withValues(alpha: 0.15),
        selectedIconTheme: IconThemeData(color: getButtonColor(context)),
        selectedLabelTextStyle: TextStyle(
          color: getButtonColor(context),
          fontWeight: FontWeight.bold,
        ),
        leading: Padding(
          padding: const EdgeInsets.symmetric(vertical: Spacing.lg),
          child: Icon(
            Icons.calendar_month_outlined,
            color: getButtonColor(context),
            size: 28,
          ),
        ),
        destinations: [
          for (final destination in _destinations)
            NavigationRailDestination(
              icon: Icon(destination.icon),
              selectedIcon: Icon(destination.selectedIcon),
              label: Text(destination.labelKey.tr()),
            ),
        ],
      ),
    );
  }
}
