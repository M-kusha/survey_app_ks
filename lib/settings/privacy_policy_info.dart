import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/layout/page_body.dart';
import 'package:echomeet/core/navigation/public_routes.dart';
import 'package:flutter/material.dart';

/// Public release-status route for a future owner-approved privacy policy.
///
/// The repository can provide a stable route and a source-level inventory, but
/// it cannot supply the operator's legal identity or make legal commitments.
/// The copy therefore fails closed and never presents itself as an approved
/// privacy policy while those release inputs are absent.
class PrivacyPolicyInfoPage extends StatelessWidget {
  const PrivacyPolicyInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('privacy_policy_title'.tr())),
      body: SafeArea(
        child: PageBody(
          maxWidth: 720,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PrivacySection(
                icon: Icons.pending_actions_rounded,
                title: 'privacy_policy_release_status_title'.tr(),
                body: 'privacy_policy_release_status_body'.tr(),
              ),
              const SizedBox(height: Spacing.md),
              _PrivacySection(
                icon: Icons.inventory_2_outlined,
                title: 'privacy_policy_source_title'.tr(),
                body: 'privacy_policy_source_body'.tr(),
              ),
              const SizedBox(height: Spacing.md),
              _PrivacySection(
                icon: Icons.fact_check_outlined,
                title: 'privacy_policy_owner_input_title'.tr(),
                body: 'privacy_policy_owner_input_body'.tr(),
              ),
              const SizedBox(height: Spacing.xl),
              OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(
                  context,
                  PublicRoutePaths.accountDeletion,
                ),
                icon: const Icon(Icons.delete_outline_rounded),
                label: Text('privacy_policy_deletion_link'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
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
