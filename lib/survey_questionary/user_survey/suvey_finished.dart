import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:survey_app_ks/settings/font_size_provider.dart';
import 'package:survey_app_ks/survey_questionary/main_sruvey/survey_main.dart';
import 'package:survey_app_ks/survey_questionary/utilities/survey_questionary_class.dart';
import 'package:survey_app_ks/utilities/tablet_size.dart';

class FinieshSurveyMessage extends StatefulWidget {
  final Participant participant;
  const FinieshSurveyMessage({
    super.key,
    required this.participant,
  });

  @override
  State<FinieshSurveyMessage> createState() => _FinieshSurveyMessageState();
}

class _FinieshSurveyMessageState extends State<FinieshSurveyMessage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);
    return Scaffold(
      appBar: AppBar(
        title: Text('survey_finished'.tr()),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'thank_you'.tr(),
              style: TextStyle(
                  fontSize: timeFontSize + 2, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Text(
              widget.participant.name,
              style: TextStyle(
                  fontSize: timeFontSize + 2, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'survey_finished_message'.tr(),
                style: TextStyle(
                  fontSize: timeFontSize + 2,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
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
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const QuestionarySurveyPageUI(),
                  ),
                  (route) => false,
                );
              },
              child: Text('return_back'.tr(),
                  style: TextStyle(fontSize: timeFontSize)),
            ),
          ],
        ),
      ),
    );
  }
}
