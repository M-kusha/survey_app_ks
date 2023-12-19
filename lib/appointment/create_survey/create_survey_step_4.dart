import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:survey_app_ks/appointment/create_survey/create_survey_step_5.dart';
import 'package:survey_app_ks/appointment/survey_class.dart';
import 'package:survey_app_ks/settings/font_size_provider.dart';
import 'package:survey_app_ks/utilities/tablet_size.dart';
import 'package:uuid/uuid.dart';

List<Survey> surveyList = [];

class CreateSurveyStep4 extends StatefulWidget {
  const CreateSurveyStep4({
    Key? key,
    required this.onSurveyCreated,
  }) : super(key: key);

  final Function(Survey) onSurveyCreated;

  @override
  State<CreateSurveyStep4> createState() => CreateSurveyStep4State();
}

class CreateSurveyStep4State extends State<CreateSurveyStep4> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  void onAddSurveyToList(Survey survey) {
    setState(() {
      surveyList.add(survey);
    });
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'validate_survey_password'.tr();
    }

    final RegExp regex =
        RegExp(r'^(?=.*?[A-Z])(?=.*?[0-9]).{6,}$', caseSensitive: false);
    if (!regex.hasMatch(value)) {
      return 'validate_survey_password_strong'.tr();
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);

    final Survey newSurvey =
        ModalRoute.of(context)?.settings.arguments as Survey;
    return Scaffold(
      appBar: AppBar(
        title: Text('create_survey_step_1'.tr(),
            style: TextStyle(fontSize: timeFontSize)),
        centerTitle: true,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16.0),
                Text(
                  'set_survey_password'.tr(),
                  style: TextStyle(fontSize: timeFontSize + 2),
                ),
                const SizedBox(height: 16.0),
                Text(
                  'survey_password_tip'.tr(),
                  style: TextStyle(fontSize: timeFontSize),
                ),
                const SizedBox(height: 50.0),
                TextFormField(
                  style: TextStyle(fontSize: timeFontSize),
                  focusNode: FocusNode(),
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'label_survey_password'.tr(),
                    labelStyle: TextStyle(fontSize: timeFontSize),
                  ),
                  obscureText: true,
                  validator: _validatePassword,
                  onChanged: (value) => newSurvey.password = value,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  style: TextStyle(fontSize: timeFontSize),
                  controller: _confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: 'label_survey_password_confirm'.tr(),
                    labelStyle: TextStyle(fontSize: timeFontSize),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return 'validate_survey_password_different'.tr();
                    }
                    return _validatePassword(value);
                  },
                  onChanged: (value) => _formKey.currentState?.validate(),
                ),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.3,
                  child: Text(
                    '',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          ),
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
              child:
                  Text('next'.tr(), style: TextStyle(fontSize: timeFontSize)),
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  final String code = const Uuid().v1().substring(0, 6);
                  newSurvey.id = code;

                  Map<String, dynamic> surveyData = newSurvey.toFirestore();

                  // Save the survey to Firestore
                  await FirebaseFirestore.instance
                      .collection('surveys')
                      .add(surveyData);

                  widget.onSurveyCreated(newSurvey);
                  onAddSurveyToList(newSurvey);
                  if (!mounted) return;

                  // Navigate to the next step
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreateSurveyStep5(
                        survey: newSurvey,
                      ),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 16.0),
          ],
        ),
      ),
    );
  }
}
