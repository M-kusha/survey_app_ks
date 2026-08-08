import 'package:flutter/widgets.dart';

/// Window size classes, using Material 3's published breakpoints rather than
/// numbers invented for this app.
///
/// Screens should branch on intent — "is there room for two panes?" — not on
/// raw pixel arithmetic. The app previously had exactly one breakpoint
/// (`shortestSide >= 600`) and it only changed font size, so a tablet got a
/// phone layout with slightly bigger text and the web build got a phone layout
/// stretched across the whole monitor.
enum WindowSize {
  /// Phones. Single column, bottom navigation.
  compact,

  /// Large phones in landscape, small tablets. Single column, navigation rail.
  medium,

  /// Tablets and small laptops. Room for list + detail side by side.
  expanded,

  /// Desktop and web. Extended rail with labels.
  large;

  static WindowSize fromWidth(double width) {
    if (width < 600) return WindowSize.compact;
    if (width < 840) return WindowSize.medium;
    if (width < 1200) return WindowSize.expanded;
    return WindowSize.large;
  }

  /// Whether a bottom navigation bar is the right control at this size.
  /// Above compact, a rail wastes less vertical space and reads as designed.
  bool get usesBottomNavigation => this == WindowSize.compact;

  /// Whether the rail should show labels beside its icons.
  bool get usesExtendedRail => this == WindowSize.large;

  /// Whether there is room to show a list and a detail pane together.
  bool get canShowTwoPanes => index >= WindowSize.expanded.index;
}

extension WindowSizeContext on BuildContext {
  /// The current window size class.
  ///
  /// Reads `MediaQuery.sizeOf`, so a widget using this rebuilds when the window
  /// resizes but not when unrelated MediaQuery fields change.
  WindowSize get windowSize =>
      WindowSize.fromWidth(MediaQuery.sizeOf(this).width);

  bool get isCompact => windowSize == WindowSize.compact;
  bool get canShowTwoPanes => windowSize.canShowTwoPanes;
}

/// Multipliers applied to the user's chosen base font size.
///
/// Multiplicative, not additive. The previous `+4 on tablet / -2 on phone`
/// added the same number of points to every text style, so a 12pt caption and a
/// 24pt heading both grew by 4 and the hierarchy between them flattened out.
extension WindowSizeTypography on WindowSize {
  double get textScale => switch (this) {
    WindowSize.compact => 1.0,
    WindowSize.medium => 1.1,
    WindowSize.expanded => 1.15,
    WindowSize.large => 1.2,
  };
}

/// Spacing scale. One set of numbers instead of every file inventing its own
/// EdgeInsets value.
abstract final class Spacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}
