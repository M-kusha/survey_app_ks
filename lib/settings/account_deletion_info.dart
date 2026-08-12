import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/layout/page_body.dart';
import 'package:echomeet/core/navigation/public_routes.dart';
import 'package:echomeet/utilities/bottom_navigation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AccountDeletionInfoPage extends StatelessWidget {
  const AccountDeletionInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final signedIn = FirebaseAuth.instance.currentUser?.emailVerified == true;

    return Scaffold(
      appBar: AppBar(title: Text('account_deletion_info_title'.tr())),
      body: SafeArea(
        child: PageBody(
          maxWidth: 720,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'account_deletion_info_intro'.tr(),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: Spacing.xl),
              _InfoSection(
                icon: Icons.format_list_numbered_rounded,
                title: 'account_deletion_steps_title'.tr(),
                body: [
                  '1. ${'account_deletion_step_1'.tr()}',
                  '2. ${'account_deletion_step_2'.tr()}',
                  '3. ${'account_deletion_step_3'.tr()}',
                ].join('\n'),
              ),
              const SizedBox(height: Spacing.md),
              _InfoSection(
                icon: Icons.delete_forever_outlined,
                title: 'account_deletion_data_title'.tr(),
                body: 'account_deletion_data_body'.tr(),
              ),
              const SizedBox(height: Spacing.md),
              _InfoSection(
                icon: Icons.domain_disabled_outlined,
                title: 'account_deletion_owner_title'.tr(),
                body: 'account_deletion_owner_body'.tr(),
              ),
              const SizedBox(height: Spacing.md),
              _InfoSection(
                icon: Icons.lock_person_outlined,
                title: 'account_deletion_access_title'.tr(),
                body: 'account_deletion_access_body'.tr(),
              ),
              const SizedBox(height: Spacing.xl),
              FilledButton.icon(
                onPressed: () => signedIn
                    ? Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute<void>(
                          builder: (context) =>
                              const BottomNavigation(initialIndex: 3),
                        ),
                        (route) => false,
                      )
                    : Navigator.pushNamed(context, '/login'),
                icon: Icon(
                  signedIn ? Icons.settings_outlined : Icons.login_rounded,
                ),
                label: Text(
                  (signedIn
                          ? 'account_deletion_open_settings'
                          : 'account_deletion_sign_in')
                      .tr(),
                ),
              ),
              const SizedBox(height: Spacing.sm),
              TextButton(
                onPressed: () => Navigator.pushNamed(
                  context,
                  PublicRoutePaths.privacyPolicy,
                ),
                child: Text('privacy_policy_link'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
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
