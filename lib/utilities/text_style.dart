// create a text style to be used in the app with all imports
import 'package:flutter/material.dart';
import 'package:survey_app_ks/utilities/colors.dart';

TextStyle textStyle = const TextStyle(
  color: Colors.black45,
  fontWeight: FontWeight.bold,
);

IconThemeData myIconTheme = const IconThemeData(
  color: Color.fromARGB(255, 108, 37, 37),
  size: 30,
);

Divider dividerSettings = const Divider(
  height: 20,
);

SizedBox sizedBoxSettings = const SizedBox(
  height: 10,
);

SizedBox sizedBoxSettingsSmall = const SizedBox(
  height: 10,
);

SizedBox sizeSettingsLarge = const SizedBox(
  height: 40,
);

Color getButtonColor(BuildContext context) {
  return ThemeBasedAppColors.getColor(context, 'buttonColor');
}

Color getListTileColor(BuildContext context) {
  return ThemeBasedAppColors.getColor(context, 'listTileColor');
}

Color getTextColor(BuildContext context) {
  return ThemeBasedAppColors.getColor(context, 'textColor');
}

// get appbar color
Color getAppbarColor(BuildContext context) {
  return ThemeBasedAppColors.getColor(context, 'appbarColor');
}

Color getCameraColor(BuildContext context) {
  return ThemeBasedAppColors.getColor(context, 'cameraIconColor');
}

Color getIconColor(BuildContext context) {
  return ThemeBasedAppColors.getColor(context, 'iconColor');
}

Color getCardColor(BuildContext context) {
  return ThemeBasedAppColors.getColor(context, 'cardColor');
}
