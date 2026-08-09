import 'package:flutter/widgets.dart';

enum WindowSize {
  compact,

  medium,

  expanded,

  large;

  static WindowSize fromWidth(double width) {
    if (width < 600) return WindowSize.compact;
    if (width < 840) return WindowSize.medium;
    if (width < 1200) return WindowSize.expanded;
    return WindowSize.large;
  }

  bool get usesBottomNavigation => this == WindowSize.compact;

  bool get usesExtendedRail => this == WindowSize.large;

  bool get canShowTwoPanes => index >= WindowSize.expanded.index;
}

extension WindowSizeContext on BuildContext {
  WindowSize get windowSize =>
      WindowSize.fromWidth(MediaQuery.sizeOf(this).width);

  bool get isCompact => windowSize == WindowSize.compact;
  bool get canShowTwoPanes => windowSize.canShowTwoPanes;
}

extension WindowSizeTypography on WindowSize {
  double get textScale => switch (this) {
    WindowSize.compact => 1.0,
    WindowSize.medium => 1.1,
    WindowSize.expanded => 1.15,
    WindowSize.large => 1.2,
  };
}

abstract final class Spacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}
