import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:ntfy_dart/ntfy_dart.dart';
import 'package:survey_app_ks/settings/font_size_provider.dart';
import 'package:survey_app_ks/survey_questionary/utilities/survey_questionary_class.dart';
import 'package:survey_app_ks/utilities/ntfy_interface.dart';
import 'package:survey_app_ks/utilities/tablet_size.dart';

class CreateTrainingSurveyStep3 extends StatefulWidget {
  final SurveyQuestionaryType survey;

  const CreateTrainingSurveyStep3({
    Key? key,
    required this.survey,
  }) : super(key: key);

  @override
  State<CreateTrainingSurveyStep3> createState() =>
      _CreateTrainingSurveyStep3State();
}

class _CreateTrainingSurveyStep3State extends State<CreateTrainingSurveyStep3> {
  final _ntfy = NtfyInterface();

  Future<void> _sendNotification() async {
    final message = PublishableMessage(
      topic: 'Intranet',
      title: 'new_survey'.tr(),
      message:
          '${'a_new_survey'.tr()} ${widget.survey.surveyName} ${'is_available'.tr()}\n${'go_to_survey'.tr()}\n ${'survey_id_is'.tr()} ${widget.survey.id}',
    );

    await _ntfy.publish(message);
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);
    double boxHeight = MediaQuery.of(context).size.width < 600
        ? timeFontSize * 1
        : timeFontSize * 1.5;

    double textFontSize = MediaQuery.of(context).size.width < 600
        ? timeFontSize * 1
        : timeFontSize * 1.5;
    Color textColor = Theme.of(context).brightness == Brightness.light
        ? const Color(0xff004B96)
        : Colors.white;

    double spacerHeight = MediaQuery.of(context).size.width < 600 ? 150 : 250;

    return Scaffold(
      appBar: AppBar(
        title: Text('create_survey_step_1'.tr(),
            style: TextStyle(fontSize: timeFontSize * 1.5)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          SizedBox(
            child: Padding(
              padding: EdgeInsets.all(boxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'survey_created_successfully'.tr(),
                    style: TextStyle(
                        fontSize: textFontSize + 2,
                        fontWeight: FontWeight.bold,
                        color: textColor),
                  ),
                  SizedBox(height: boxHeight),
                  Text(
                    'your_id_information'.tr(),
                    style: TextStyle(
                        fontSize: textFontSize,
                        fontWeight: FontWeight.bold,
                        color: textColor),
                  ),
                  SizedBox(height: boxHeight),
                  Text(
                    'share_id_information'.tr(),
                    style: TextStyle(
                      fontSize: textFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: spacerHeight),
                ],
              ),
            ),
          ),
          SizedBox(height: boxHeight),
          SizedBox(
            child: GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: widget.survey.id));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                    'survey_id_copied'.tr(),
                    style: TextStyle(
                      fontSize: textFontSize,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ));
              },
              child: Align(
                alignment: Alignment.center, // Align text to the center
                child: Text(
                  '${'survey_id'.tr()} ${widget.survey.id}',
                  style: TextStyle(
                      fontSize: textFontSize,
                      fontWeight: FontWeight.bold,
                      color: textColor),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: Size.fromHeight(timeFontSize * 3.0),
                padding: EdgeInsets.symmetric(vertical: timeFontSize * 0.5),
              ),
              onPressed: () {
                _sendNotification();
                Navigator.of(context) // pop until root
                  ..popUntil((route) => route.isFirst)
                  ..pushNamed('/questionary_survey');
              },
              child: Text('finish'.tr(),
                  style: TextStyle(
                    fontSize: textFontSize,
                  )),
            ),
            const SizedBox(height: 16.0),
          ],
        ),
      ),
    );
  }
}
