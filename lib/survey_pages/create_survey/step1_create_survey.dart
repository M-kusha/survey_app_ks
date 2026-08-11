import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/widgets/app_text_field.dart';
import 'package:echomeet/core/widgets/wizard_scaffold.dart';
import 'package:echomeet/survey_pages/create_survey/step2_create_survey.dart';
import 'package:echomeet/survey_pages/utilities/survey_questionary_class.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class Step1CreateSurvey extends StatefulWidget {
  const Step1CreateSurvey({super.key, this.template});

  /// A survey to start from, when the author chose to duplicate one.
  ///
  /// It arrives already stripped of everything that identified the original,
  /// and always with a fresh deadline. Published surveys cannot be edited, so
  /// duplicating drops the author into this wizard rather than publishing a
  /// copy outright — the name, the timing and the questions all need a look
  /// before anyone is asked to answer them again.
  final Survey? template;

  @override
  Step1CreateSurveyState createState() => Step1CreateSurveyState();
}

class Step1CreateSurveyState extends State<Step1CreateSurvey> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.template?.surveyName ?? '',
  );
  late final _description = TextEditingController(
    text: widget.template?.surveyDescription ?? '',
  );

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _next() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final template = widget.template;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Step2CreateSurvey(
          survey: Survey(
            surveyName: _name.text.trim(),
            surveyDescription: _description.text.trim(),
            timeCreated: DateTime.now(),
            // Copied, not shared: the template belongs to the survey still
            // listed on the previous screen.
            questions: [...?template?.questions],
            id: const Uuid().v4(),

            deadline: DateTime.now().add(const Duration(days: 7)),
            participants: [],
            timeLimitPerQuestion: template?.timeLimitPerQuestion ?? 0,
            surveyType: template?.surveyType ?? SurveyType.survey,
            companyId: '',
          ),
          onSurveyCreated: (survey) => Navigator.pop(context, survey),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return WizardScaffold(
      step: 1,
      totalSteps: 3,
      appBarTitle: 'create_survey'.tr(),
      title: 'create_survey_step1_title'.tr(),
      subtitle: 'create_survey_step1_subhead'.tr(),
      primaryLabel: 'next'.tr(),
      onPrimary: _next,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              label: 'survey_title'.tr(),
              controller: _name,
              icon: Icons.title_rounded,
              textInputAction: TextInputAction.next,
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'survey_name_error'.tr()
                  : null,
            ),
            const SizedBox(height: Spacing.md),
            Text(
              'survey_description'.tr().toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Spacing.sm),
            TextFormField(
              controller: _description,
              maxLines: null,
              minLines: 4,
              maxLength: 1000,
              keyboardType: TextInputType.multiline,
              style: theme.textTheme.bodyLarge,
              decoration: InputDecoration(
                hintText: 'survey_description_hint'.tr(),
                alignLabelWithHint: true,
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'survey_description_error'.tr()
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
