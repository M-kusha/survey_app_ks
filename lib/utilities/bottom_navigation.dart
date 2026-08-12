import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/appointments/main_screen/appointments_dashboard.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/membership/app_banner.dart';
import 'package:echomeet/core/membership/membership.dart';
import 'package:echomeet/core/profile/authenticated_profile_image.dart';
import 'package:echomeet/notes/notes_main.dart';
import 'package:echomeet/core/theme/app_theme.dart';
import 'package:echomeet/core/widgets/language_button.dart';
import 'package:echomeet/core/widgets/sign_out_button.dart';
import 'package:echomeet/core/widgets/theme_toggle_button.dart';
import 'package:echomeet/settings/settings.dart';
import 'package:echomeet/survey_pages/main_sruvey/survey_main.dart';
import 'package:echomeet/survey_pages/utilities/survey_data_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// The extended rail's width, declared once because both `NavigationRail` and
/// the profile block sized to it have to agree.
const double _extendedRailWidth = 256;

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
          // The rail is an unconstrained child of the shell's Row, because
          // NavigationRail sizes itself from its destinations. That leaves
          // `leading` with an unbounded width, so anything flexible inside it
          // throws during layout. Naming the extended width here and sizing the
          // leading to it gives the profile row something finite to divide.
          minExtendedWidth: _extendedRailWidth,
          leading: SizedBox(
            width: extended ? _extendedRailWidth : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.sm,
                Spacing.lg,
                Spacing.sm,
                Spacing.lg,
              ),
              child: _RailProfile(
                extended: extended,
                onTap: () => _onDestinationSelected(_destinations.length - 1),
              ),
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
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.md),
            child: _RailBrand(extended: extended),
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

/// The signed-in account, at the top of the rail.
///
/// Collapsed it is the avatar alone; extended it carries the name and the
/// company. Tapping it goes to settings, which is where everything about the
/// account lives, so the obvious gesture does the obvious thing.
class _RailProfile extends StatelessWidget {
  const _RailProfile({required this.extended, required this.onTap});

  final bool extended;
  final VoidCallback onTap;

  static String _initials(String? name) {
    final parts = (name ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Nullable reads on purpose. The rail is chrome, not a feature: if a screen
    // ever hosts it without these providers it should draw a plain avatar, not
    // bring the whole shell down.
    final user = context.watch<UserDataProvider?>()?.currentUser;
    final membership = context.watch<MembershipProvider?>()?.membership;

    final avatar = ClipOval(
      child: Container(
        height: 38,
        width: 38,
        color: scheme.primaryContainer,
        alignment: Alignment.center,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Text(
                _initials(user?.name),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
            if (user?.profileImage case final stored?)
              if (stored.trim().isNotEmpty)
                AuthenticatedProfileImage(
                  storedReference: stored,
                  refreshKey: user?.profileImageRevision,
                ),
          ],
        ),
      ),
    );

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(Radii.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.sm),
          child: extended
              ? Row(
                  children: [
                    avatar,
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            user?.name ?? 'unknown'.tr(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                          if (membership?.companyName case final company?)
                            Text(
                              company,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  ],
                )
              : avatar,
        ),
      ),
    );
  }
}

/// The wordmark, at the foot of the rail where it belongs.
class _RailBrand extends StatelessWidget {
  const _RailBrand({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final glyph = Container(
      height: 26,
      width: 26,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, scheme.tertiary],
        ),
      ),
      child: Icon(
        Icons.calendar_month_rounded,
        color: scheme.onPrimary,
        size: 15,
      ),
    );

    if (!extended) return glyph;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        glyph,
        const SizedBox(width: Spacing.sm),
        Text(
          'app_title'.tr(),
          style: theme.textTheme.labelMedium?.copyWith(
            fontFamily: AppTheme.displayFontFamily,
            fontWeight: FontWeight.w700,
            color: scheme.onSurfaceVariant,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}
