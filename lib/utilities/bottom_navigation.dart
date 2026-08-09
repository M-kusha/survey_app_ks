import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/appointments/main_screen/appointments_dashboard.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/membership/app_banner.dart';
import 'package:echomeet/notes/notes_main.dart';
import 'package:echomeet/core/theme/app_theme.dart';
import 'package:echomeet/core/widgets/language_button.dart';
import 'package:echomeet/core/widgets/sign_out_button.dart';
import 'package:echomeet/core/widgets/theme_toggle_button.dart';
import 'package:echomeet/settings/settings.dart';
import 'package:echomeet/survey_pages/main_sruvey/survey_main.dart';
import 'package:flutter/material.dart';

class _Destination {
  const _Destination(this.icon, this.selectedIcon, this.labelKey);

  final IconData icon;
  final IconData selectedIcon;
  final String labelKey;
}

const _destinations = <_Destination>[
  _Destination(Icons.edit_note_rounded, Icons.sticky_note_2_rounded, 'notes'),
  _Destination(
    Icons.calendar_today_outlined,
    Icons.calendar_month_rounded,
    'appointments',
  ),
  _Destination(
    Icons.insert_chart_outlined_rounded,
    Icons.insert_chart_rounded,
    'survey',
  ),
  _Destination(Icons.settings_outlined, Icons.settings_rounded, 'settings'),
];

class BottomNavigation extends StatefulWidget {
  const BottomNavigation({super.key, this.initialIndex = 0, this.pages});

  final int initialIndex;

  final List<Widget>? pages;

  @override
  State<BottomNavigation> createState() => _BottomNavigationState();
}

class _BottomNavigationState extends State<BottomNavigation> {
  late int _currentIndex = widget.initialIndex;
  late final Set<int> _visitedIndices = {_currentIndex};

  Widget _defaultPage(int index) => switch (index) {
    0 => TodoList(),
    1 => AppointmentPageUI(),
    2 => QuestionarySurveyPageUI(),
    3 => SettingsPageUI(),
    _ => const SizedBox.shrink(),
  };

  List<Widget> _pages() {
    final pageCount = widget.pages?.length ?? _destinations.length;
    return [
      for (var index = 0; index < pageCount; index++)
        if (_visitedIndices.contains(index))
          HeroMode(
            enabled: index == _currentIndex,
            child: widget.pages?[index] ?? _defaultPage(index),
          )
        else
          const SizedBox.shrink(),
    ];
  }

  void _onDestinationSelected(int index) {
    setState(() {
      _currentIndex = index;
      _visitedIndices.add(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final windowSize = context.windowSize;

    final body = Column(
      children: [
        if (widget.pages == null) const AppBanner(),
        Expanded(
          child: IndexedStack(index: _currentIndex, children: _pages()),
        ),
      ],
    );

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

  Widget _cappedScale({required BuildContext context, required Widget child}) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        textScaler: media.textScaler.clamp(maxScaleFactor: 1.15),
      ),
      child: child,
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      child: _cappedScale(
        context: context,
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _onDestinationSelected,
          height: 66,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            for (final destination in _destinations)
              NavigationDestination(
                icon: Icon(destination.icon),
                selectedIcon: Icon(destination.selectedIcon),
                label: destination.labelKey.tr(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRail(BuildContext context, {required bool extended}) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      child: _cappedScale(
        context: context,
        child: NavigationRail(
          selectedIndex: _currentIndex,
          onDestinationSelected: _onDestinationSelected,
          extended: extended,

          labelType: extended
              ? NavigationRailLabelType.none
              : NavigationRailLabelType.all,
          leading: Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.md,
              Spacing.lg,
              Spacing.md,
              Spacing.xl,
            ),
            child: _RailBrand(extended: extended),
          ),
          destinations: [
            for (final destination in _destinations)
              NavigationRailDestination(
                icon: Icon(destination.icon),
                selectedIcon: Icon(destination.selectedIcon),
                label: Text(destination.labelKey.tr()),
              ),
          ],

          trailing: Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: Spacing.lg),
                child: _RailFooter(extended: extended),
              ),
            ),
          ),

          indicatorColor: scheme.secondaryContainer,
          selectedLabelTextStyle: theme.textTheme.labelMedium?.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelTextStyle: theme.textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _RailFooter extends StatelessWidget {
  const _RailFooter({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final controls = <Widget>[
      const ThemeToggleButton(),
      const LanguageButton(),
      const SignOutButton(),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md,
            vertical: Spacing.md,
          ),
          child: Divider(
            height: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),

        if (extended)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final control in controls)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
                  child: control,
                ),
            ],
          )
        else
          for (final control in controls)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
              child: control,
            ),
      ],
    );
  }
}

class _RailBrand extends StatelessWidget {
  const _RailBrand({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final glyph = Container(
      height: 34,
      width: 34,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, scheme.tertiary],
        ),
      ),
      child: Icon(
        Icons.calendar_month_rounded,
        color: scheme.onPrimary,
        size: 19,
      ),
    );

    if (!extended) return glyph;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        glyph,
        const SizedBox(width: Spacing.md),
        Text(
          'app_title'.tr(),
          style: theme.textTheme.titleMedium?.copyWith(
            fontFamily: AppTheme.displayFontFamily,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}
