import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/membership/company_browser.dart';
import 'package:echomeet/core/membership/membership.dart';
import 'package:echomeet/core/widgets/feature_kit.dart';
import 'package:flutter/material.dart';

/// What a tab shows instead of its content when the account cannot use it.
///
/// This has no `child`. It used to take one and return it whenever the
/// membership was null — and both callers passed `SizedBox.shrink()`, because
/// the gate is meant to *replace* the page, not wrap it. A null membership is
/// not "everything is fine": `MembershipProvider` leaves it null and records an
/// error when the read fails, so a transient Firestore failure rendered an
/// empty box. That is a blank screen with no message, no retry, and nothing in
/// the console once the error has scrolled past.
///
/// Every branch below returns something a person can act on.
class CompanyGate extends StatelessWidget {
  const CompanyGate({
    super.key,
    required this.membership,
    required this.onChanged,
  });

  final Membership? membership;

  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final membership = this.membership;

    // Unknown, because the read failed. Offering "find a company" here would
    // tell somebody who is in one that they are not, so this says only what is
    // true: it could not be loaded, try again.
    if (membership == null) {
      return _Gate(
        icon: Icons.cloud_off_rounded,
        title: 'error_occurred'.tr(),
        body: 'membership_unavailable_body'.tr(),
        actionLabel: 'retry'.tr(),
        onAction: () => onChanged(),
      );
    }

    return switch (membership.state) {
      MembershipState.pending => _Gate(
        icon: Icons.hourglass_top_rounded,
        title: 'approval_pending'.tr(),
        body: 'approval_pending_body'.tr(
          namedArgs: {'company': membership.companyName},
        ),

        actionLabel: 'leave_company'.tr(),
        onAction: () => _leave(context),
      ),
      MembershipState.banned => _Gate(
        icon: Icons.block_rounded,
        title: 'you_are_banned'.tr(),
        body: 'you_are_banned_body'.tr(
          namedArgs: {'company': membership.companyName},
        ),
        actionLabel: 'find_another_company'.tr(),
        onAction: () => _leave(context),
      ),
      _ => _Gate(
        icon: Icons.domain_add_rounded,
        title: 'no_company_title'.tr(),
        body: 'no_company_body'.tr(),
        actionLabel: 'find_a_company'.tr(),
        onAction: () => _browse(context),
      ),
    };
  }

  Future<void> _browse(BuildContext context) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const CompanyBrowserPage()));
    await onChanged();
  }

  Future<void> _leave(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await MembershipService().leaveCompany();
      if (!context.mounted) return;
      await _browse(context);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text('error_occurred'.tr())));
    }
  }
}

class _Gate extends StatelessWidget {
  const _Gate({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: EmptyState(
              icon: icon,
              title: title,
              body: body,
              action: FilledButton(
                onPressed: onAction,
                child: Text(actionLabel),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
