import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:survey_app_ks/appointment/survey_class.dart';
import 'package:survey_app_ks/appointment/user_survey/user_survey_buttons.dart';
import 'package:survey_app_ks/settings/font_size_provider.dart';
import 'package:survey_app_ks/utilities/tablet_size.dart';

class SurveyNamePage extends StatefulWidget {
  final Survey survey;
  final Participant participant;

  const SurveyNamePage({
    Key? key,
    required this.survey,
    required this.participant,
  }) : super(key: key);

  @override
  SurveyNamePageState createState() => SurveyNamePageState();
}

class SurveyNamePageState extends State<SurveyNamePage> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);
    String? userName = widget.participant
        .userName; // Retrieve the initial value of userName from participant
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'survey_participant_name'.tr(),
          style: TextStyle(fontSize: timeFontSize),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: GestureDetector(
          onTap: () {
            FocusScope.of(context).requestFocus(FocusNode());
          },
          child: Padding(
            padding: EdgeInsets.all(timeFontSize * 1.5),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: timeFontSize * 1.2),
                  Text(
                    widget.survey.title,
                    style: TextStyle(fontSize: timeFontSize + 2),
                  ),
                  SizedBox(height: timeFontSize * 1.2),
                  Text(widget.survey.description,
                      style: TextStyle(fontSize: timeFontSize)),
                  SizedBox(height: timeFontSize * 1.2),
                  TextFormField(
                    style: TextStyle(fontSize: timeFontSize),
                    decoration: InputDecoration(
                      labelText: 'survey_participant_name_label'.tr(),
                      hintStyle: TextStyle(fontSize: timeFontSize),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'survey_participant_name_error'.tr();
                      }
                      return null;
                    },
                    onSaved: (value) {
                      setState(() {
                        userName = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16.0),
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.5,
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
                if (_formKey.currentState!.validate()) {
                  _formKey.currentState!.save();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    widget.participant.userName = userName ?? "";
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SurveyUserSelectCategories(
                          survey: widget.survey,
                          userName: widget.participant.userName,
                          timeSlot: widget.participant.timeSlot,
                        ),
                      ),
                    );
                  });
                }
              },
              child:
                  Text('next'.tr(), style: TextStyle(fontSize: timeFontSize)),
            ),
          ],
        ),
      ),
    );
  }
}
