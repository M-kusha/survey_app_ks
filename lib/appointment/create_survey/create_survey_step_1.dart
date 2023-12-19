import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:survey_app_ks/appointment/survey_class.dart';
import 'package:survey_app_ks/settings/font_size_provider.dart';
import 'package:survey_app_ks/utilities/tablet_size.dart';

class CreateSurveyStep1 extends StatefulWidget {
  const CreateSurveyStep1({Key? key}) : super(key: key);

  @override
  CreateSurveyStep1State createState() => CreateSurveyStep1State();
}

// Create the state for CreateSurveyStep1
class CreateSurveyStep1State extends State<CreateSurveyStep1> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final Survey _newSurvey = Survey(
    title: '',
    description: '',
    availableDates: [],
    availableTimeSlots: [],
    password: '',
    id: '',
    expirationDate: DateTime.now(),
  );
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  int? maxLines;

  @override
  void initState() {
    super.initState();
    _descriptionController.addListener(() {
      setState(() {
        maxLines = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'create_survey_step_1'.tr(),
          style: TextStyle(fontSize: timeFontSize + 3),
        ),
        centerTitle: true,
      ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(timeFontSize * 1.5),
              child: Form(
                key: _formKey,
                child: GestureDetector(
                  onTap: () {
                    FocusScope.of(context).requestFocus(FocusNode());
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(top: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'create_survey_title'.tr(),
                          style: TextStyle(
                            fontSize: timeFontSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextFormField(
                          style: TextStyle(fontSize: timeFontSize),
                          controller: _titleController,
                          decoration: InputDecoration(
                            hintText: 'create_survey_title_hint'.tr(),
                            hintStyle: TextStyle(fontSize: timeFontSize),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'create_survey_title_error'.tr();
                            }
                            return null;
                          },
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          onChanged: (value) {
                            _newSurvey.title = value;
                          },
                        ),
                        const SizedBox(height: 20.0),
                        Text(
                          'create_survey_description'.tr(),
                          style: TextStyle(
                            fontSize: timeFontSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextFormField(
                          style: TextStyle(fontSize: timeFontSize),
                          strutStyle: const StrutStyle(
                            forceStrutHeight: true,
                            height: 1.5,
                          ),
                          controller: _descriptionController,
                          maxLength: 256,
                          maxLines: maxLines,
                          decoration: InputDecoration(
                            hintText: 'create_survey_description_hint'.tr(),
                            hintStyle: TextStyle(fontSize: timeFontSize * 1.2),
                            counterText:
                                '${_descriptionController.text.length}/256',
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'create_survey_description_error'.tr();
                            }
                            return null;
                          },
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          onChanged: (value) {
                            setState(() {
                              _newSurvey.description = value;
                            });
                          },
                          onTap: () {
                            setState(() {
                              maxLines = null;
                            });
                          },
                          onEditingComplete: () {
                            setState(() {
                              maxLines = 1;
                            });
                          },
                        ),
                        SizedBox(
                          height: constraints.maxHeight * 0.4,
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
            ),
          );
        },
      ),
      // Bottom navigation bar with an ElevatedButton
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            minimumSize: Size.fromHeight(timeFontSize * 3.0),
            padding: EdgeInsets.symmetric(vertical: timeFontSize * 0.5),
          ),
          onPressed: () {
            if (_titleController.text.isEmpty ||
                _descriptionController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'create_survey_error_snackbar'.tr(),
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  backgroundColor:
                      Theme.of(context).brightness == Brightness.light
                          ? const Color(0xff004B96)
                          : Colors.white,
                ),
              );
            } else if (_formKey.currentState!.validate()) {
              Navigator.pushNamed(
                context,
                '/create_survey_2',
                arguments: _newSurvey,
              );
            }
          },
          child: Text('next'.tr(), style: TextStyle(fontSize: timeFontSize)),
        ),
      ),
    );
  }
}
