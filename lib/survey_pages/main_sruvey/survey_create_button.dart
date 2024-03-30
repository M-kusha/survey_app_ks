import 'package:echomeet/utilities/text_style.dart';
import 'package:flutter/material.dart';

Widget buildCreateQuestionarySurveyButton(BuildContext context) {
  return FloatingActionButton(
    backgroundColor: getButtonColor(context),
    onPressed: () =>
        Navigator.of(context).pushNamed('/create_training_survey_1'),
    tooltip: 'Add Survey',
    child: Icon(Icons.add, color: getTextColor(context)),
  );
}
