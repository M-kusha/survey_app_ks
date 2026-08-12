import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/layout/page_body.dart';
import 'package:echomeet/core/navigation/public_routes.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PrivacyPolicyInfoPage extends StatelessWidget {
  const PrivacyPolicyInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('privacy_policy_title'.tr())),
      body: SafeArea(
        child: PageBody(
          maxWidth: 720,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'privacy_policy_summary'.tr(),
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                'privacy_policy_effective'.tr(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Spacing.xl),
              _PrivacySection(
                icon: Icons.person_outline_rounded,
                title: 'privacy_policy_operator_title'.tr(),
                body: 'privacy_policy_operator_body'.tr(),
              ),
              const SizedBox(height: Spacing.md),
              _PrivacySection(
                icon: Icons.inventory_2_outlined,
                title: 'privacy_policy_data_title'.tr(),
                body: 'privacy_policy_data_body'.tr(),
              ),
              const SizedBox(height: Spacing.md),
              _PrivacySection(
                icon: Icons.visibility_outlined,
                title: 'privacy_policy_visibility_title'.tr(),
                body: 'privacy_policy_visibility_body'.tr(),
              ),
              const SizedBox(height: Spacing.md),
              _PrivacySection(
                icon: Icons.do_not_disturb_on_outlined,
                title: 'privacy_policy_no_tracking_title'.tr(),
                body: 'privacy_policy_no_tracking_body'.tr(),
              ),
              const SizedBox(height: Spacing.md),
              _PrivacySection(
                icon: Icons.gavel_outlined,
                title: 'privacy_policy_rights_title'.tr(),
                body: 'privacy_policy_rights_body'.tr(),
              ),
              const SizedBox(height: Spacing.xl),
              FilledButton.icon(
                onPressed: _openFullPolicy,
                icon: const Icon(Icons.open_in_new_rounded),
                label: Text('privacy_policy_full_link'.tr()),
              ),
              const SizedBox(height: Spacing.sm),
              SelectableText(
                PublicRoutePaths.privacyPolicyUrl,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Spacing.md),
              TextButton(
                onPressed: () => Navigator.pushNamed(
                  context,
                  PublicRoutePaths.accountDeletion,
                ),
                child: Text('privacy_policy_deletion_link'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openFullPolicy() async {
    try {
      await launchUrl(
        Uri.parse(PublicRoutePaths.privacyPolicyUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }
}

class _PrivacySection extends StatelessWidget {
  const _PrivacySection({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: scheme.primary),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: Spacing.sm),
                  Text(body),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
