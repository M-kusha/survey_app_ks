import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:survey_app_ks/appointment/survey_class.dart';
import 'package:survey_app_ks/settings/font_size_provider.dart';
import 'package:survey_app_ks/utilities/tablet_size.dart';

class SurveyEditPageStep1 extends StatefulWidget {
  final Survey survey;
  final Function(int) onPageChange;

  const SurveyEditPageStep1({
    Key? key,
    required this.survey,
    required this.onPageChange,
  }) : super(key: key);

  @override
  SurveyEditPageStep1State createState() => SurveyEditPageStep1State();
}

class SurveyEditPageStep1State extends State<SurveyEditPageStep1> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.survey.title);
    _descriptionController =
        TextEditingController(text: widget.survey.description);
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);
    int? maxLines;

    return SingleChildScrollView(
      child: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  TextFormField(
                    style: TextStyle(fontSize: timeFontSize),
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'create_survey_title'.tr(),
                      labelStyle: TextStyle(
                        fontSize: timeFontSize,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'create_survey_title_error'.tr();
                      }
                      return null;
                    },
                    onChanged: (value) {
                      setState(() {
                        widget.survey.title = value;
                      });
                    },
                  ),
                  TextFormField(
                    style: TextStyle(fontSize: timeFontSize),
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      labelText: 'create_survey_description'.tr(),
                      labelStyle: TextStyle(
                        fontSize: timeFontSize,
                      ),
                      counterText: '${_descriptionController.text.length}/256',
                    ),
                    maxLength: 256,
                    maxLines: maxLines,
                    onChanged: (value) {
                      setState(() {
                        widget.survey.description = value;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'create_survey_description_error'.tr();
                      }
                      return null;
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
                    height: MediaQuery.of(context).size.height * 0.4,
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
  }
}
