import 'package:flutter/material.dart';

class ThemeBasedAppColors {
  static final Map<String, Color> _lightThemeColors = {
    'primary': const Color(0xFF654321),
    'secondary': const Color(0xFFFEDCBA),
    'buttonColor': Colors.blueAccent,
    'textColor': Colors.white,
  };

  static final Map<String, Color> _darkThemeColors = {
    'primary': const Color(0xFF123456),
    'secondary': const Color(0xFFABCDEF),
    'buttonColor': Colors.tealAccent,
    'textColor': Colors.grey[900] ?? Colors.black,
    'backgroundColor': Colors.grey[900] ?? Colors.black,
  };

  static Color getColor(BuildContext context, String colorKey) {
    if (Theme.of(context).brightness == Brightness.dark) {
      return _darkThemeColors[colorKey] ??
          Colors.black; // Default to black if colorKey not found
    } else {
      return _lightThemeColors[colorKey] ??
          Colors.white; // Default to white if colorKey not found
    }
  }
}
