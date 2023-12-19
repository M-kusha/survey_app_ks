import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:survey_app_ks/appointment/survey_class.dart';
import 'package:survey_app_ks/settings/font_size_provider.dart';
import 'package:survey_app_ks/utilities/tablet_size.dart';

class SurveyEditPageStep3 extends StatefulWidget {
  final Survey survey;
  final Function(int) onPageChange;

  const SurveyEditPageStep3({
    Key? key,
    required this.survey,
    required this.onPageChange,
  }) : super(key: key);

  @override
  SurveyEditPageStep3State createState() => SurveyEditPageStep3State();
}

class SurveyEditPageStep3State extends State<SurveyEditPageStep3> {
  final _formKey = GlobalKey<FormState>();
  late String _password;

  @override
  void initState() {
    super.initState();
    _password = widget.survey.password;
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
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16.0),
                Text(
                  'edit_survey_password'.tr(),
                  style: TextStyle(
                    fontSize: timeFontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16.0),
                Text(
                  'edit_survey_password_tip'.tr(),
                  style: TextStyle(
                    fontSize: timeFontSize - 3,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 50.0),
                TextFormField(
                  style: TextStyle(
                    fontSize: timeFontSize,
                  ),
                  focusNode: FocusNode(),
                  initialValue: widget.survey.password,
                  decoration: InputDecoration(
                    labelText: 'label_survey_password'.tr(),
                    labelStyle: TextStyle(
                      fontSize: timeFontSize,
                    ),
                  ),
                  obscureText: true,
                  validator: _validatePassword,
                  onChanged: (value) => _password = value,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  style: TextStyle(
                    fontSize: timeFontSize,
                  ),
                  initialValue: widget.survey.password,
                  decoration: InputDecoration(
                    labelText: 'label_survey_password_confirm'.tr(),
                    labelStyle: TextStyle(
                      fontSize: timeFontSize,
                    ),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value != _password) {
                      return 'validate_survey_password_different'.tr();
                    }
                    return _validatePassword(value);
                  },
                  onChanged: (value) => _formKey.currentState?.validate(),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size.fromHeight(timeFontSize * 3.0),
                    padding: EdgeInsets.symmetric(vertical: timeFontSize * 0.5),
                  ),
                  onPressed: () {
                    if (_formKey.currentState?.validate() ?? false) {
                      widget.survey.password = _password;
                    }
                    // show a snackbar with if the password was changed
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'survey_password_changed'.tr(),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  },
                  child: Text('update'.tr(),
                      style: TextStyle(fontSize: timeFontSize)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
