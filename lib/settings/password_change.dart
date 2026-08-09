import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/layout/page_body.dart';
import 'package:echomeet/core/widgets/app_text_field.dart';
import 'package:echomeet/core/widgets/glass_panel.dart';
import 'package:echomeet/core/widgets/password_strength_meter.dart';
import 'package:echomeet/utilities/reusable_widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PasswordChanger extends StatefulWidget {
  const PasswordChanger({super.key, required this.isSuperAdmin});

  final bool isSuperAdmin;

  @override
  State<PasswordChanger> createState() => _PasswordChangerState();
}

class _PasswordChangerState extends State<PasswordChanger> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  bool _visible = false;
  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final email = user?.email;
      if (user == null || email == null) {
        throw FirebaseAuthException(code: 'no-current-user');
      }

      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: _current.text),
      );
      await user.updatePassword(_next.text);

      if (!mounted) return;
      UIUtils.showSnackBar(context, 'password_updated_success'.tr());
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      UIUtils.showSnackBar(context, switch (e.code) {
        'wrong-password' || 'invalid-credential' => 'invalid_old_password'.tr(),
        'weak-password' => 'validate_password_strong'.tr(),
        'requires-recent-login' => 'invalid_old_password'.tr(),
        _ => 'error_occurred'.tr(),
      });
    } catch (_) {
      if (!mounted) return;
      UIUtils.showSnackBar(context, 'error_occurred'.tr());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('change_password'.tr())),
      body: SafeArea(
        child: PageBody(
          maxWidth: 460,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: Spacing.md),
              Text(
                'change_password_hint'.tr(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Spacing.lg),
              GlassPanel(
                padding: const EdgeInsets.all(Spacing.xl),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppTextField(
                        label: 'current_password'.tr(),
                        controller: _current,
                        icon: Icons.lock_outline_rounded,
                        obscure: !_visible,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.next,
                        validator: (value) => (value == null || value.isEmpty)
                            ? 'password_empty'.tr()
                            : null,
                        trailing: _VisibilityToggle(
                          visible: _visible,
                          onChanged: (v) => setState(() => _visible = v),
                        ),
                      ),
                      const SizedBox(height: Spacing.md),
                      AppTextField(
                        label: 'set_new_password'.tr(),
                        controller: _next,
                        icon: Icons.lock_reset_rounded,
                        obscure: !_visible,
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'password_empty'.tr();
                          }
                          if (value == _current.text) {
                            return 'password_same_as_old'.tr();
                          }
                          return PasswordStrengthMeter.isStrongEnough(value)
                              ? null
                              : 'validate_password_strong'.tr();
                        },
                      ),

                      ValueListenableBuilder(
                        valueListenable: _next,
                        builder: (context, value, _) =>
                            PasswordStrengthMeter(password: value.text),
                      ),
                      const SizedBox(height: Spacing.md),
                      AppTextField(
                        label: 'confirm_password'.tr(),
                        controller: _confirm,
                        icon: Icons.check_circle_outline_rounded,
                        obscure: !_visible,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        validator: (value) => value == _next.text
                            ? null
                            : 'passwords_dont_match'.tr(),
                      ),
                      const SizedBox(height: Spacing.md),
                      GlowButton(
                        onPressed: _saving ? null : _submit,
                        busy: _saving,
                        label: 'change_password'.tr(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Spacing.xxl),
            ],
          ),
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
