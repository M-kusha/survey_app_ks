import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/layout/page_body.dart';
import 'package:echomeet/core/membership/company_privilege_service.dart';
import 'package:echomeet/core/widgets/app_text_field.dart';
import 'package:echomeet/core/widgets/glass_panel.dart';
import 'package:echomeet/utilities/reusable_widgets.dart';
import 'package:flutter/material.dart';

String companyCreationFailureKey(CompanyCreationFailure failure) =>
    switch (failure) {
      CompanyCreationFailure.invalidName => 'company_name_invalid',
      CompanyCreationFailure.nameTaken => 'company_name_taken',
      CompanyCreationFailure.ineligible => 'create_company_ineligible',
      CompanyCreationFailure.recentLoginRequired =>
        'create_company_recent_login',
      CompanyCreationFailure.accountUnavailable =>
        'create_company_account_unavailable',
      CompanyCreationFailure.invalidCredential => 'invalid_current_password',
      CompanyCreationFailure.unavailable => 'create_company_unavailable',
    };

class CreateCompanyPage extends StatefulWidget {
  const CreateCompanyPage({super.key, this.service});

  final CompanyPrivilegeService? service;

  @override
  State<CreateCompanyPage> createState() => _CreateCompanyPageState();
}

class _CreateCompanyPageState extends State<CreateCompanyPage> {
  final _formKey = GlobalKey<FormState>();
  final _companyName = TextEditingController();
  final _password = TextEditingController();

  late final CompanyPrivilegeService _service;
  bool _passwordVisible = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? CompanyPrivilegeService();
  }

  @override
  void dispose() {
    _companyName.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    try {
      final receipt = await _service.createCompany(
        companyName: _companyName.text,
        password: _password.text,
      );
      _password.clear();
      if (!mounted) return;
      Navigator.of(context).pop(receipt);
    } on CompanyCreationException catch (error) {
      if (!mounted) return;
      UIUtils.showSnackBar(
        context,
        companyCreationFailureKey(error.failure).tr(),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text('create_company'.tr())),
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
                    'create_company_hint'.tr(),
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
                          label: 'company_name'.tr(),
                          controller: _companyName,
                          icon: Icons.business_outlined,
                          textInputAction: TextInputAction.next,
                          enabled: !_saving,
                          maxLength:
                              CompanyPrivilegeService.maxCompanyNameLength,
                          validator: (value) =>
                              CompanyPrivilegeService.isValidCompanyName(
                                value ?? '',
                              )
                              ? null
                              : 'company_name_invalid'.tr(),
                        ),
                        const SizedBox(height: Spacing.sm),
                        AppTextField(
                          label: 'current_password'.tr(),
                          controller: _password,
                          icon: Icons.lock_outline_rounded,
                          obscure: !_passwordVisible,
                          autofillHints: const [AutofillHints.password],
                          textInputAction: TextInputAction.done,
                          enabled: !_saving,
                          onSubmitted: (_) => _submit(),
                          validator: (value) => value?.isNotEmpty == true
                              ? null
                              : 'password_empty'.tr(),
                          trailing: IconButton(
                            tooltip: _passwordVisible
                                ? 'hide_password'.tr()
                                : 'show_password'.tr(),
                            onPressed: _saving
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
                              Icons.verified_user_outlined,
                              size: 18,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: Spacing.sm),
                            Expanded(
                              child: Text(
                                'create_company_owner_notice'.tr(),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: Spacing.lg),
                        GlowButton(
                          onPressed: _saving ? null : _submit,
                          busy: _saving,
                          label: 'create_company'.tr(),
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
