import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/layout/page_body.dart';
import 'package:echomeet/core/security/email_change_service.dart';
import 'package:echomeet/core/widgets/app_text_field.dart';
import 'package:echomeet/core/widgets/glass_panel.dart';
import 'package:echomeet/survey_pages/utilities/survey_data_provider.dart';
import 'package:echomeet/utilities/reusable_widgets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

String emailChangeFailureKey(EmailChangeFailure failure) => switch (failure) {
  EmailChangeFailure.invalidEmail => 'email_change_invalid',
  EmailChangeFailure.unchangedEmail => 'email_change_same',
  EmailChangeFailure.invalidCredential => 'invalid_current_password',
  EmailChangeFailure.emailAlreadyInUse => 'email_change_already_in_use',
  EmailChangeFailure.recentLoginRequired => 'email_change_recent_login',
  EmailChangeFailure.accountUnavailable => 'email_change_account_unavailable',
  EmailChangeFailure.emailNotVerified ||
  EmailChangeFailure.verificationPending => 'email_change_not_yet_verified',
  EmailChangeFailure.unavailable => 'email_change_unavailable',
};

class ChangeEmailPage extends StatefulWidget {
  const ChangeEmailPage({super.key, this.service});

  final EmailChangeService? service;

  @override
  State<ChangeEmailPage> createState() => _ChangeEmailPageState();
}

class _ChangeEmailPageState extends State<ChangeEmailPage> {
  final _formKey = GlobalKey<FormState>();
  final _newEmail = TextEditingController();
  final _password = TextEditingController();

  late final EmailChangeService _service;
  bool _passwordVisible = false;
  bool _requesting = false;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? EmailChangeService();
  }

  @override
  void dispose() {
    _newEmail.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _requestChange() async {
    if (_requesting || _syncing) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _requesting = true);

    try {
      final receipt = await _service.requestChange(
        newEmail: _newEmail.text,
        password: _password.text,
      );
      _newEmail.text = receipt.newEmail;
      _password.clear();
      if (!mounted) return;
      UIUtils.showSnackBar(
        context,
        'email_change_request_sent'.tr(namedArgs: {'email': receipt.newEmail}),
      );
    } on EmailChangeException catch (error) {
      if (!mounted) return;
      UIUtils.showSnackBar(context, emailChangeFailureKey(error.failure).tr());
    } catch (_) {
      if (!mounted) return;
      UIUtils.showSnackBar(context, 'email_change_unavailable'.tr());
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  Future<void> _syncVerifiedChange() async {
    if (_requesting || _syncing) return;
    final expectedEmail = EmailChangeService.normalizeEmail(_newEmail.text);
    if (!EmailChangeService.isValidEmail(expectedEmail)) {
      UIUtils.showSnackBar(context, 'email_change_invalid'.tr());
      return;
    }
    setState(() => _syncing = true);

    try {
      final receipt = await _service.syncVerifiedEmail(
        expectedEmail: expectedEmail,
      );
      if (!mounted) return;
      if (receipt.changed) {
        await context.read<UserDataProvider>().loadCurrentUser();
        if (!mounted) return;
        UIUtils.showSnackBar(context, 'email_change_synced'.tr());
      } else {
        UIUtils.showSnackBar(context, 'email_change_already_synced'.tr());
      }
    } on EmailChangeException catch (error) {
      if (!mounted) return;
      UIUtils.showSnackBar(context, emailChangeFailureKey(error.failure).tr());
    } catch (_) {
      if (!mounted) return;
      UIUtils.showSnackBar(context, 'email_change_unavailable'.tr());
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final busy = _requesting || _syncing;

    return Scaffold(
      appBar: AppBar(title: Text('change_email'.tr())),
      body: SafeArea(
        child: PageBody(
          maxWidth: 480,
          child: AutofillGroup(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: Spacing.md),
                  Text(
                    'change_email_hint'.tr(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: Spacing.lg),
                  GlassPanel(
                    padding: const EdgeInsets.all(Spacing.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppTextField(
                          label: 'new_email'.tr(),
                          controller: _newEmail,
                          icon: Icons.alternate_email_rounded,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: TextInputAction.next,
                          enabled: !busy,
                          maxLength: EmailChangeService.maxEmailLength,
                          validator: (value) =>
                              EmailChangeService.isValidEmail(value ?? '')
                              ? null
                              : 'email_change_invalid'.tr(),
                        ),
                        const SizedBox(height: Spacing.sm),
                        AppTextField(
                          label: 'current_password'.tr(),
                          controller: _password,
                          icon: Icons.lock_outline_rounded,
                          obscure: !_passwordVisible,
                          autofillHints: const [AutofillHints.password],
                          textInputAction: TextInputAction.done,
                          enabled: !busy,
                          onSubmitted: (_) => _requestChange(),
                          validator: (value) => value?.isNotEmpty == true
                              ? null
                              : 'password_empty'.tr(),
                          trailing: IconButton(
                            tooltip: _passwordVisible
                                ? 'hide_password'.tr()
                                : 'show_password'.tr(),
                            onPressed: busy
                                ? null
                                : () => setState(
                                    () => _passwordVisible = !_passwordVisible,
                                  ),
                            icon: Icon(
                              _passwordVisible
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                        const SizedBox(height: Spacing.sm),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.mark_email_unread_outlined,
                              size: 18,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: Spacing.sm),
                            Expanded(
                              child: Text(
                                'change_email_old_address_notice'.tr(),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: Spacing.lg),
                        GlowButton(
                          onPressed: busy ? null : _requestChange,
                          busy: _requesting,
                          label: 'change_email_send_link'.tr(),
                        ),
                        const SizedBox(height: Spacing.md),
                        OutlinedButton.icon(
                          onPressed: busy ? null : _syncVerifiedChange,
                          icon: _syncing
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.verified_outlined),
                          label: Text('email_change_verified_action'.tr()),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Spacing.xxl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
