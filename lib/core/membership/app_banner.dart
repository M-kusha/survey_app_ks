import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/membership/company_admin_service.dart';
import 'package:echomeet/core/membership/membership.dart';
import 'package:echomeet/core/theme/app_colors.dart';
import 'package:echomeet/settings/user_menagment.dart';
import 'package:echomeet/utilities/firebase_services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AppBanner extends StatefulWidget {
  const AppBanner({super.key});

  @override
  State<AppBanner> createState() => _AppBannerState();
}

class _AppBannerState extends State<AppBanner> {
  final _service = CompanyAdminService();

  Membership? _membership;
  int _pending = 0;
  bool _canManagePeople = false;
  bool _closing = false;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _load();

    _tick = Timer.periodic(const Duration(minutes: 2), (_) => _load());
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (FirebaseAuth.instance.currentUser == null) return;

    try {
      final membership = await MembershipService().resolve();
      final canManagePeople = await FirebaseServices().canManagePeople();

      final pending = canManagePeople && membership.companyId.isNotEmpty
          ? await _service.pendingCount(membership.companyId)
          : 0;

      if (!mounted) return;
      setState(() {
        _membership = membership;
        _canManagePeople = canManagePeople;
        _pending = pending;
      });

      await _runClosureIfDue(membership, canManagePeople);
    } catch (_) {}
  }

  Future<void> _runClosureIfDue(Membership membership, bool canManage) async {
    final at = membership.deletionAt;
    if (at == null || at.isAfter(DateTime.now())) return;
    if (_closing) return;

    _closing = true;
    try {
      if (canManage) {
        await _service.purgeCompany(membership.companyId);
      } else {
        await MembershipService().leaveCompany();
      }
      if (!mounted) return;
      setState(() => _membership = null);
      await _load();
    } catch (_) {
    } finally {
      _closing = false;
    }
  }

  Future<void> _cancelClosure() async {
    final companyId = _membership?.companyId ?? '';
    if (companyId.isEmpty) return;

    try {
      await _service.cancelDeletion(companyId);
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('error_occurred'.tr())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final membership = _membership;

    if (membership != null && membership.isClosing) {
      final days = membership.deletionAt!.difference(DateTime.now()).inDays;

      return _Strip(
        icon: Icons.warning_amber_rounded,
        tone: Theme.of(context).colorScheme.error,
        message: 'company_closing_banner'.tr(
          namedArgs: {
            'company': membership.companyName,
            'days': '${days < 0 ? 0 : days}',
          },
        ),
        actionLabel: _canManagePeople ? 'cancel_deletion'.tr() : null,
        onAction: _canManagePeople ? _cancelClosure : null,
      );
    }

    if (_pending > 0) {
      return _Strip(
        icon: Icons.person_add_alt_1_rounded,
        tone: context.appColors.warning,
        message: 'pending_approvals_banner'.tr(
          namedArgs: {'count': '$_pending'},
        ),
        actionLabel: 'review'.tr(),
        onAction: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => UserManagementPage(
                userId: FirebaseAuth.instance.currentUser?.uid ?? '',
              ),
            ),
          );
          await _load();
        },
      );
    }

    return const SizedBox.shrink();
  }
}

class _Strip extends StatelessWidget {
  const _Strip({
    required this.icon,
    required this.tone,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final Color tone;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: tone.withValues(alpha: 0.12),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.md,
            Spacing.sm,
            Spacing.sm,
            Spacing.sm,
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: tone),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(color: tone),
                ),
              ),
              if (actionLabel case final label?)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(foregroundColor: tone),
                  child: Text(label),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
