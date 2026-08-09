import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/widgets/app_text_field.dart';
import 'package:echomeet/register/register_3step.dart';
import 'package:echomeet/register/register_logics.dart';
import 'package:echomeet/register/register_shell.dart';
import 'package:flutter/material.dart';

class Register2step extends StatefulWidget {
  final RegisterLogic registerLogic;
  final ProfileType profileType;

  const Register2step({
    super.key,
    required this.registerLogic,
    required this.profileType,
  });

  @override
  State<Register2step> createState() => _Register2stepState();
}

class _Register2stepState extends State<Register2step> {
  final _formKey = GlobalKey<FormState>();

  RegisterLogic get _logic => widget.registerLogic;
  bool get _registeringCompany => widget.profileType == ProfileType.company;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  void _next() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Register3step(
          registerLogic: _logic,
          profileType: widget.profileType,
        ),
      ),
    );
  }

  Future<void> _pickBirthdate() async {
    final now = DateTime.now();

    final latest = DateTime(now.year - 18, now.month, now.day);

    final chosen = await showDatePicker(
      context: context,
      initialDate: latest,
      firstDate: DateTime(1900),
      lastDate: latest,
    );
    if (chosen == null || !mounted) return;

    setState(() {
      _logic.birthdateController.text = DateFormat.yMMMMd().format(chosen);
    });
  }

  @override
  Widget build(BuildContext context) {
    return RegisterShell(
      step: 2,
      titleKey: 'register_step2_title',
      subtitleKey: 'register_step2_subhead',
      continueLabelKey: 'next',
      onContinue: _next,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              label: 'fullname'.tr(),
              controller: _logic.fullnameController,
              icon: Icons.person_outline_rounded,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'please_fill_all_fields'.tr()
                  : null,
            ),
            const SizedBox(height: Spacing.sm),

            _BirthdateField(
              controller: _logic.birthdateController,
              onTap: _pickBirthdate,
            ),
            const SizedBox(height: Spacing.sm),
            AppTextField(
              label: 'email'.tr(),
              controller: _logic.emailController,
              icon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: _registeringCompany
                  ? TextInputAction.next
                  : TextInputAction.done,
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty) return 'please_fill_all_fields'.tr();
                return _emailPattern.hasMatch(email)
                    ? null
                    : 'invalid_email_message'.tr();
              },
            ),
            if (_registeringCompany) ...[
              const SizedBox(height: Spacing.sm),
              AppTextField(
                label: 'company_name'.tr(),
                controller: _logic.companyNameController,
                icon: Icons.business_outlined,
                textInputAction: TextInputAction.done,
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'please_fill_all_fields'.tr()
                    : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BirthdateField extends StatelessWidget {
  const _BirthdateField({required this.controller, required this.onTap});

  final TextEditingController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        child: AppTextField(
          label: 'birthdate'.tr(),
          controller: controller,
          icon: Icons.cake_outlined,
          validator: (value) => (value == null || value.trim().isEmpty)
              ? 'please_fill_all_fields'.tr()
              : null,
        ),
      ),
    );
  }
}
