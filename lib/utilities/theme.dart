import 'package:flutter/material.dart';

final darkTheme = ThemeData.dark().copyWith(
  brightness: Brightness.dark,
  primaryColor: Colors.black,
  colorScheme: ColorScheme.fromSwatch().copyWith(secondary: Colors.grey[800]),
);

final lightTheme = ThemeData.light().copyWith(
  brightness: Brightness.light,
  primaryColor: const Color(0xFF004B96),
  colorScheme: ColorScheme.fromSwatch().copyWith(secondary: Colors.grey[400]),
);
