import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/appointments/main_screen/appointments_dashboard.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/membership/app_banner.dart';
import 'package:echomeet/core/membership/membership.dart';
import 'package:echomeet/core/profile/authenticated_profile_image.dart';
import 'package:echomeet/core/widgets/brand_mark.dart';
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

const double _extendedRailWidth = 256;

const Key bottomNavigationBarKey = Key('echomeet.bottomNavigationBar');

const double _compactRailHeight = 500;

class _Destination {
  const _Destination(
    this.icon,
    this.selectedIcon,
    this.labelKey,
    this.shortLabelKey,
  );

  final IconData icon;
  final IconData selectedIcon;
  final String labelKey;

  final String shortLabelKey;
}

const _destinations = <_Destination>[
  _Destination(
    Icons.edit_note_rounded,
    Icons.sticky_note_2_rounded,
    'notes',
    'nav_notes',
  ),
  _Destination(
    Icons.calendar_today_outlined,
    Icons.calendar_month_rounded,
    'appointments',
    'nav_appointments',
  ),
  _Destination(
    Icons.insert_chart_outlined_rounded,
    Icons.insert_chart_rounded,
    'survey',
    'nav_surveys',
  ),
  _Destination(
    Icons.settings_outlined,
    Icons.settings_rounded,
    'settings',
    'nav_settings',
  ),
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

  Widget _cappedScale({
    required BuildContext context,
    required Widget child,
    double maxScale = 1.15,
  }) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        textScaler: media.textScaler.clamp(maxScaleFactor: maxScale),
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
        maxScale: 1.1,
        child: _BottomBar(
          currentIndex: _currentIndex,
          onSelected: _onDestinationSelected,
        ),
      ),
    );
  }

  Widget _buildRail(BuildContext context, {required bool extended}) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final short =
              constraints.maxHeight.isFinite &&
              constraints.maxHeight < _compactRailHeight;
          return _cappedScale(
            context: context,
            child: _rail(context, extended: extended, short: short),
          );
        },
      ),
    );
  }

  Widget _rail(
    BuildContext context, {
    required bool extended,
    required bool short,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return NavigationRail(
      selectedIndex: _currentIndex,
      onDestinationSelected: _onDestinationSelected,
      extended: extended,
      scrollable: true,
      labelType: extended
          ? NavigationRailLabelType.none
          : NavigationRailLabelType.all,
      minExtendedWidth: _extendedRailWidth,
      leading: SizedBox(
        width: extended ? _extendedRailWidth : null,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            Spacing.sm,
            short ? Spacing.sm : Spacing.lg,
            Spacing.sm,
            short ? Spacing.sm : Spacing.lg,
          ),
          child: _RailProfile(
            extended: extended,
            compact: short,
            onTap: () => _onDestinationSelected(_destinations.length - 1),
          ),
        ),
      ),
      destinations: [
        for (final destination in _destinations)
          NavigationRailDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon),
            label: Text(
              destination.labelKey.tr(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
      ],
      trailingAtBottom: true,
      trailing: short
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(bottom: Spacing.lg),
              child: _RailFooter(extended: extended),
            ),
      indicatorColor: scheme.secondaryContainer,
      selectedLabelTextStyle: theme.textTheme.labelMedium?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: theme.textTheme.labelMedium?.copyWith(
        color: scheme.onSurfaceVariant,
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

class _RailProfile extends StatelessWidget {
  const _RailProfile({
    required this.extended,
    required this.onTap,
    this.compact = false,
  });

  final bool extended;
  final VoidCallback onTap;
  final bool compact;

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

    final user = context.watch<UserDataProvider?>()?.currentUser;
    final membership = context.watch<MembershipProvider?>()?.membership;

    final diameter = compact ? 28.0 : 36.0;

    final avatar = ClipOval(
      child: Container(
        height: diameter,
        width: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.8),
          ),
        ),
        alignment: Alignment.center,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Text(
                _initials(user?.name),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
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

class _RailBrand extends StatelessWidget {
  const _RailBrand({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75);

    if (!extended) return BrandMark(size: 24, color: muted);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandMark(size: 22, color: muted),
        const SizedBox(width: Spacing.sm),
        Text(
          'app_title'.tr(),
          style: theme.textTheme.labelMedium?.copyWith(
            fontFamily: AppTheme.displayFontFamily,
            fontWeight: FontWeight.w600,
            color: muted,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.currentIndex, required this.onSelected});

  final int currentIndex;
  final ValueChanged<int> onSelected;

  static const double _height = 66;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      key: bottomNavigationBarKey,

      color: scheme.navSurface,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: _height,
          child: Row(
            children: [
              for (final (index, destination) in _destinations.indexed)
                Expanded(
                  child: _BottomBarItem(
                    destination: destination,
                    selected: index == currentIndex,
                    position: index,
                    total: _destinations.length,
                    onTap: () => onSelected(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomBarItem extends StatelessWidget {
  const _BottomBarItem({
    required this.destination,
    required this.selected,
    required this.position,
    required this.total,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final int position;
  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = destination.shortLabelKey.tr();

    return Semantics(
      selected: selected,
      button: true,
      inMutuallyExclusiveGroup: true,
      label: label,
      container: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        excludeFromSemantics: true,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
              decoration: BoxDecoration(
                color: selected
                    ? scheme.primary.withValues(alpha: 0.14)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              child: Icon(
                selected ? destination.selectedIcon : destination.icon,
                size: 22,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 3),

            Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
