import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/membership/company_admin_service.dart';
import 'package:echomeet/core/membership/membership.dart';
import 'package:echomeet/core/theme/app_colors.dart';
import 'package:echomeet/settings/user_menagment.dart';
import 'package:echomeet/survey_pages/utilities/survey_data_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AppBanner extends StatefulWidget {
  const AppBanner({super.key});

  @override
  State<AppBanner> createState() => _AppBannerState();
}

class _AppBannerState extends State<AppBanner> {
  final _service = CompanyAdminService();

  int _pending = 0;
  Timer? _tick;
  int _pendingGeneration = 0;
  String? _inputsKey;
  bool _refreshScheduled = false;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(
      const Duration(minutes: 2),
      (_) => _refreshPending(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final membershipState = context.watch<MembershipProvider>();
    final user = context.watch<UserDataProvider>().currentUser;
    final membership = membershipState.membership;
    final inputsKey = [
      membershipState.loading,
      membership?.companyId,
      membership?.state,
      membership?.deletionAt,
      user?.id,
      user?.role,
    ].join('|');

    if (_inputsKey == inputsKey) return;
    _inputsKey = inputsKey;
    _schedulePendingRefresh();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _schedulePendingRefresh() {
    if (_refreshScheduled) return;
    _refreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshScheduled = false;
      if (mounted) _refreshPending();
    });
  }

  Future<void> _refreshPending() async {
    if (!mounted) return;
    final generation = ++_pendingGeneration;
    final membership = context.read<MembershipProvider>().membership;
    final role = context.read<UserDataProvider>().currentUser?.role;
    final canManagePeople = role == 'admin' || role == 'superadmin';

    var pending = 0;
    try {
      if (canManagePeople &&
          membership != null &&
          membership.companyId.isNotEmpty &&
          (membership.deletionAt?.isAfter(DateTime.now()) ?? true)) {
        pending = await _service.pendingCount(membership.companyId);
      }
    } catch (_) {
      return;
    }

    if (!mounted || generation != _pendingGeneration || pending == _pending) {
      return;
    }
    setState(() => _pending = pending);
  }

  Future<void> _cancelClosure() async {
    final companyId =
        context.read<MembershipProvider>().membership?.companyId ?? '';
    if (companyId.isEmpty) return;

    try {
      await _service.cancelDeletion(companyId);
      await _refreshPending();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('error_occurred'.tr())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final membership = context.watch<MembershipProvider>().membership;
    final role = context.watch<UserDataProvider>().currentUser?.role;
    final canManagePeople = role == 'admin' || role == 'superadmin';
    final canCancelClosure = role == 'superadmin';

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
        actionLabel: canCancelClosure ? 'cancel_deletion'.tr() : null,
        onAction: canCancelClosure ? _cancelClosure : null,
      );
    }

    if (canManagePeople && _pending > 0) {
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
          await _refreshPending();
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
