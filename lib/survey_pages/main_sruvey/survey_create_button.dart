import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/widgets/feature_kit.dart';
import 'package:flutter/material.dart';

Widget buildCreateQuestionarySurveyButton(BuildContext context) {
  return CreateFab(
    heroTag: 'surveys-create-fab',
    label: 'create_survey'.tr(),
    onPressed: () =>
        Navigator.of(context).pushNamed('/create_training_survey_1'),
  );
}
