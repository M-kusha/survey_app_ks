import 'package:flutter/material.dart';

double getTimeFontSize(BuildContext context, double fontSize) {
  final mediaQuery = MediaQuery.of(context);
  double timeFontSize = fontSize;
  if (mediaQuery.size.shortestSide >= 600) {
    // tablet
    timeFontSize += 4; // increase font size by 4 points
  } else {
    // phone
    timeFontSize -= 2; // decrease font size by 2 points
  }
  return timeFontSize;
}
