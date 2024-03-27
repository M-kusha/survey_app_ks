import 'package:flutter/material.dart';

import 'package:survey_app_ks/utilities/colors.dart';

Widget buildCreateQuestionarySurveyButton(BuildContext context) {
  return FloatingActionButton(
    backgroundColor: ThemeBasedAppColors.getColor(
        context, 'buttonColor'), // Saturated color for light theme
    onPressed: () =>
        Navigator.of(context).pushNamed('/create_training_survey_1'),
    tooltip: 'Add Survey',
    child: Icon(
      Icons.add,
      color: ThemeBasedAppColors.getColor(context, 'textColor'),
    ),
  );
}
