import 'package:flutter/material.dart';

double getTimeFontSize(BuildContext context, double fontSize) {
  final mediaQuery = MediaQuery.of(context);
  double timeFontSize = fontSize;
  if (mediaQuery.size.shortestSide >= 600) {
    timeFontSize += 4;
  } else {
    timeFontSize -= 2;
  }
  return timeFontSize;
}
