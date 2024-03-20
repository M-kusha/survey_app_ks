import 'package:flutter/material.dart';

class ThemeBasedAppColors {
  static final Map<String, Color> _lightThemeColors = {
    'primary': const Color(0xFF654321),
    'secondary': const Color(0xFFFEDCBA),
    'buttonColor': Colors.blueGrey,
    'listTileColor': Colors.blueGrey,
    'textColor': Colors.white,
    'appbarColor': Colors.grey[100] ?? Colors.white,
    'selectedColor': Colors.white,
    'errorColor': Colors.red,
    'snackBarColor': Colors.white,
    'dateColor': Colors.white,
    'listparticipatedColor': Colors.green,
    'listnotparticipatedColor': Colors.white,
    "cameraIconColor": Colors.blueGrey,
  };

  static final Map<String, Color> _darkThemeColors = {
    'primary': const Color(0xFF123456),
    'secondary': const Color(0xFFABCDEF),
    'buttonColor': Colors.tealAccent,
    'listTileColor': Colors.white,
    'textColor': Colors.grey[900] ?? Colors.black,
    'appbarColor': Colors.grey[900] ?? Colors.black,
    'selectedColor': Colors.grey[900] ?? Colors.black,
    'errorColor': Colors.red,
    'snackBarColor': Colors.grey[900] ?? Colors.black,
    'dateColor': Colors.grey[900] ?? Colors.black,
    'listparticipatedColor': Colors.green,
    'listnotparticipatedColor': Colors.white,
    "cameraIconColor": Colors.blueGrey,
  };

  static Color getColor(BuildContext context, String colorKey) {
    var themeColors = Theme.of(context).brightness == Brightness.dark
        ? _darkThemeColors
        : _lightThemeColors;
    return themeColors[colorKey] ?? Colors.blue;
  }
}
