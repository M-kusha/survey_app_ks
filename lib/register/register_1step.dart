import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/theme/app_theme.dart';
import 'package:echomeet/register/register_2step.dart';
import 'package:echomeet/register/register_logics.dart';
import 'package:echomeet/register/register_shell.dart';
import 'package:flutter/material.dart';

class Register1step extends StatefulWidget {
  final RegisterLogic registerLogic;

  const Register1step({super.key, required this.registerLogic});

  @override
  Register1stepState createState() => Register1stepState();
}

class Register1stepState extends State<Register1step> {
  ProfileType? _selectedType;

  void _next() {
    final type = _selectedType;
    if (type == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Register2step(
          registerLogic: widget.registerLogic,
          profileType: type,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RegisterShell(
      step: 1,
      titleKey: 'register_step1_title',
      subtitleKey: 'register_step1_subhead',
      continueLabelKey: 'next',

      onContinue: _selectedType == null ? null : _next,
      footer: _AlreadyHaveAnAccount(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ChoiceCard(
            icon: Icons.rocket_launch_rounded,
            title: 'register_as_company'.tr(),
            body: 'register_as_company_body'.tr(),
            selected: _selectedType == ProfileType.company,
            onTap: () => setState(() => _selectedType = ProfileType.company),
          ),
          const SizedBox(height: Spacing.md),
          _ChoiceCard(
            icon: Icons.group_add_rounded,
            title: 'register_as_user'.tr(),
            body: 'register_as_user_body'.tr(),
            selected: _selectedType == ProfileType.user,
            onTap: () => setState(() => _selectedType = ProfileType.user),
          ),
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.lg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.lg),
            color: selected
                ? scheme.primary.withValues(alpha: 0.10)
                : Colors.transparent,
            border: Border.all(
              color: selected
                  ? scheme.primary
                  : scheme.outlineVariant.withValues(alpha: 0.8),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 24,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(
                width: 24,
                child: selected
                    ? Icon(
                        Icons.check_circle_rounded,
                        size: 20,
                        color: scheme.primary,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlreadyHaveAnAccount extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'already_have_account'.tr(),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: Text('login_title'.tr()),
        ),
      ],
    );
  }
}
