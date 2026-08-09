import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/widgets/app_text_field.dart';
import 'package:echomeet/core/widgets/password_strength_meter.dart';
import 'package:echomeet/register/register_4step.dart';
import 'package:echomeet/register/register_logics.dart';
import 'package:echomeet/register/register_shell.dart';
import 'package:echomeet/register/registered_sucesfully.dart';
import 'package:echomeet/utilities/reusable_widgets.dart';
import 'package:flutter/material.dart';
import 'package:password_strength/password_strength.dart';

class Register3step extends StatefulWidget {
  final RegisterLogic registerLogic;
  final ProfileType profileType;

  const Register3step({
    super.key,
    required this.registerLogic,
    required this.profileType,
  });

  @override
  Register3stepState createState() => Register3stepState();
}

class Register3stepState extends State<Register3step> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _visible = false;
  bool _saving = false;

  static const _minimum = PasswordStrengthMeter.minimum;

  bool get _isCompany => widget.profileType == ProfileType.company;
  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    widget.registerLogic.passwordController.text = _passwordController.text;

    if (_isCompany) {
      _finish();
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            Register4step(registerLogic: widget.registerLogic),
      ),
    );
  }

  Future<void> _finish() async {
    setState(() => _saving = true);

    try {
      await widget.registerLogic.registerUser(profileType: widget.profileType);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const RegistrationSuccessPage(),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      UIUtils.showSnackBar(context, registrationErrorKey(e).tr());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RegisterShell(
      step: 3,
      titleKey: 'register_step3_title',
      subtitleKey: 'register_step3_subhead',
      continueLabelKey: _isCompany ? 'finish_registration' : 'next',
      onContinue: _saving ? null : _submit,
      busy: _saving,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              label: 'set_your_password'.tr(),
              controller: _passwordController,
              icon: Icons.lock_outline_rounded,
              obscure: !_visible,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'password_empty'.tr();
                }
                return estimatePasswordStrength(value) < _minimum
                    ? 'validate_password_strong'.tr()
                    : null;
              },
              trailing: _VisibilityToggle(
                visible: _visible,
                onChanged: (value) => setState(() => _visible = value),
              ),
            ),

            ValueListenableBuilder(
              valueListenable: _passwordController,
              builder: (context, _, _) =>
                  PasswordStrengthMeter(password: _passwordController.text),
            ),
            const SizedBox(height: Spacing.md),
            AppTextField(
              label: 'confirm_password'.tr(),
              controller: _confirmController,
              icon: Icons.lock_reset_rounded,
              obscure: !_visible,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              validator: (value) => value == _passwordController.text
                  ? null
                  : 'passwords_dont_match'.tr(),
              trailing: _VisibilityToggle(
                visible: _visible,
                onChanged: (value) => setState(() => _visible = value),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VisibilityToggle extends StatelessWidget {
  const _VisibilityToggle({required this.visible, required this.onChanged});

  final bool visible;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        size: 19,
      ),
      onPressed: () => onChanged(!visible),
    );
  }
}
