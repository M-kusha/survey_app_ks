import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/settings/font_size_provider.dart';
import 'package:echomeet/survey_pages/utilities/survey_questionary_class.dart';
import 'package:echomeet/utilities/bottom_navigation.dart';
import 'package:echomeet/utilities/reusable_widgets.dart';
import 'package:echomeet/utilities/tablet_size.dart';
import 'package:echomeet/utilities/text_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class Step4CreateSurvey extends StatefulWidget {
  final Survey survey;

  const Step4CreateSurvey({super.key, required this.survey});

  @override
  State<Step4CreateSurvey> createState() => Step4CreateSurveyState();
}

class Step4CreateSurveyState extends State<Step4CreateSurvey> {
  void _onNextPressed() async {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const BottomNavigation(initialIndex: 2),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fontSizeProvider = Provider.of<FontSizeProvider>(context);
    final fontSize = fontSizeProvider.fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);

    return Scaffold(
      appBar: AppBar(
          title: Text(
            'create_survey'.tr(),
            style: TextStyle(
              fontSize: timeFontSize * 1.5,
            ),
          ),
          centerTitle: true,
          backgroundColor: getAppbarColor(context)),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Card(
              elevation: 5,
              shadowColor: getButtonColor(context),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: timeFontSize * 3,
                      color: getButtonColor(context),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      widget.survey.surveyType == SurveyType.survey
                          ? 'survey_created_successfully'.tr()
                          : 'test_created_successfully'.tr(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: timeFontSize * 1.2,
                          fontWeight: FontWeight.bold,
                          color: getListTileColor(context)),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      widget.survey.surveyType == SurveyType.survey
                          ? 'share_id_information_survey'.tr()
                          : 'share_id_information_test'.tr(),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: timeFontSize),
                    ),
                    const SizedBox(height: 30),
                    Container(
                      decoration: BoxDecoration(
                        color: getCardColor(context),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: getButtonColor(context)),
                      ),
                      child: InkWell(
                        onTap: () => copyToClipboard(
                            context, widget.survey.id, timeFontSize),
                        child: Container(
                          decoration: BoxDecoration(
                            color: getAppbarColor(context),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 20),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.content_copy,
                                  size: timeFontSize * 1.2),
                              const SizedBox(width: 10),
                              Text(
                                widget.survey.surveyType == SurveyType.survey
                                    ? '${'survey_id'.tr()} ${widget.survey.id}'
                                    : '${'test_id'.tr()} ${widget.survey.id}',
                                style: TextStyle(fontSize: timeFontSize - 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: buildBottomElevatedButton(
        context: context,
        onPressed: _onNextPressed,
        buttonText: 'finish',
      ),
    );
  }

  Widget buildInformationCard(BuildContext context,
      {required String title,
      required String subtitle,
      required IconData iconData,
      required double fontSize}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(iconData, size: fontSize * 1.5),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: fontSize, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(subtitle, style: TextStyle(fontSize: fontSize)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void copyToClipboard(BuildContext context, String text, double fontSize) {
    Clipboard.setData(ClipboardData(text: text));
    UIUtils.showSnackBar(context, 'appointment_id_copied');
  }
}
