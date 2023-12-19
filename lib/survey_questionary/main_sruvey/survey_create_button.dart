import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:survey_app_ks/settings/font_size_provider.dart';

Widget buildCreateQuestionarySurveyButton(BuildContext context) {
  final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
  final screenWidth = MediaQuery.of(context).size.width;
  final timeFontSize = screenWidth < 600
      ? (fontSize.clamp(00.0, 15.0))
      : (fontSize.clamp(00.0, 30.0));
  return SizedBox(
    width: MediaQuery.of(context).size.width / 1.5,
    child: Padding(
      padding: EdgeInsets.all(timeFontSize * 1.5),
      child: ElevatedButton(
        style: ButtonStyle(
          backgroundColor: Theme.of(context).brightness == Brightness.light
              ? MaterialStateProperty.all(
                  const Color(0xFF28B4E6),
                )
              : MaterialStateProperty.all(
                  Colors.grey[900],
                ),
          shape: MaterialStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
          ),
          minimumSize: MaterialStateProperty.all(
            Size(
              MediaQuery.of(context).size.width / 1.5,
              timeFontSize * 3.5,
            ),
          ),
          padding: MaterialStateProperty.all(
            EdgeInsets.all(timeFontSize * 1),
          ),
        ),
        onPressed: () {
          Navigator.of(context).pushNamed('/create_training_survey_1');
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'create_survey_step_1'.tr(),
              style: TextStyle(
                fontSize: timeFontSize,
                color: Theme.of(context).brightness == Brightness.light
                    ? Colors.white
                    : Colors.white,
              ),
            ),
            const SizedBox(width: 8.0),
            Icon(
              Icons.add,
              color: Theme.of(context).brightness == Brightness.light
                  ? Colors.white
                  : Colors.white,
            ),
          ],
        ),
      ),
    ),
  );
}
