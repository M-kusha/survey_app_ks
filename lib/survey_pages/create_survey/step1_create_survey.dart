import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:survey_app_ks/settings/font_size_provider.dart';
import 'package:survey_app_ks/survey_pages/create_survey/step2_create_survey.dart';
import 'package:survey_app_ks/utilities/reusable_widgets.dart';
import 'package:survey_app_ks/survey_pages/utilities/survey_questionary_class.dart';
import 'package:survey_app_ks/utilities/text_style.dart';
import 'package:uuid/uuid.dart';

class Step1CreateSurvey extends StatefulWidget {
  const Step1CreateSurvey({Key? key}) : super(key: key);

  @override
  Step1CreateSurveyState createState() => Step1CreateSurveyState();
}

class Step1CreateSurveyState extends State<Step1CreateSurvey> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _surveyNameController = TextEditingController();
  final TextEditingController _surveyDescriptionController =
      TextEditingController();

  void _onNextPressed() {
    if (_formKey.currentState!.validate()) {
      final survey = Survey(
        surveyName: _surveyNameController.text,
        surveyDescription: _surveyDescriptionController.text,
        timeCreated: DateTime.now(),
        questions: [],
        id: const Uuid().v4(),
        deadline: DateTime.now(),
        participants: [],
        companyId: '',
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Step2CreateSurvey(
            survey: survey,
            onSurveyCreated: (survey) {
              Navigator.pop(context, survey);
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'create_survey'.tr(),
          style: TextStyle(
            fontSize: fontSize * 1.5,
          ),
        ),
        backgroundColor: getAppbarColor(context),
        centerTitle: true,
      ),
      body: Center(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(fontSize * 1.5),
                child: Card(
                  elevation: 5,
                  shadowColor: getButtonColor(context),
                  child: Form(
                    key: _formKey,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _surveyNameController,
                            decoration: InputDecoration(
                              hintText: 'survey_title'.tr(),
                              hintStyle: TextStyle(fontSize: fontSize),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'survey_name_error'.tr();
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20.0),
                          TextFormField(
                            controller: _surveyDescriptionController,
                            maxLength: 1000,
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            decoration: InputDecoration(
                              hintText: 'survey_description'.tr(),
                              hintStyle: TextStyle(fontSize: fontSize),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'survey_description_error'.tr();
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: constraints.maxHeight * 0.4),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: buildBottomElevatedButton(
        context: context,
        onPressed: _onNextPressed,
        buttonText: 'next',
      ),
    );
  }
}
