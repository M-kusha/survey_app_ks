import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/layout/page_body.dart';
import 'package:echomeet/core/membership/company_admin_service.dart';
import 'package:echomeet/core/widgets/feature_kit.dart';
import 'package:flutter/material.dart';

class BannedMembersPage extends StatefulWidget {
  const BannedMembersPage({super.key, required this.companyId});

  final String companyId;

  @override
  State<BannedMembersPage> createState() => _BannedMembersPageState();
}

class _BannedMembersPageState extends State<BannedMembersPage> {
  final _service = CompanyAdminService();

  List<BannedMember> _members = [];
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });

    try {
      final members = await _service.bannedMembers(widget.companyId);
      if (!mounted) return;
      setState(() {
        _members = members;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _loading = false;
      });
    }
  }

  Future<void> _unban(BannedMember member) async {
    try {
      await _service.unban(member.userId);
      if (!mounted) return;
      setState(() => _members.removeWhere((m) => m.userId == member.userId));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ban_lifted'.tr())));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('error_occurred'.tr())));
    }
  }

  Future<void> _erase(BannedMember member) async {
    final firstGate = await showDialog<bool>(
      context: context,
      builder: (context) => _WarningDialog(
        title: 'erase_member_data'.tr(),
        body: 'erase_warning_1'.tr(namedArgs: {'name': member.name}),
        confirmLabel: 'continue'.tr(),
      ),
    );
    if (firstGate != true || !mounted) return;

    final secondGate = await showDialog<bool>(
      context: context,
      builder: (context) => _WarningDialog(
        title: 'erase_member_data'.tr(),
        body: 'erase_warning_2'.tr(namedArgs: {'name': member.name}),
        confirmLabel: 'erase'.tr(),
      ),
    );
    if (secondGate != true || !mounted) return;

    final wentAhead = await showDialog<bool>(
      context: context,

      barrierDismissible: false,
      builder: (context) => _CountdownDialog(name: member.name),
    );
    if (wentAhead != true || !mounted) return;

    try {
      await _service.erase(member.userId);
      if (!mounted) return;
      setState(() => _members.removeWhere((m) => m.userId == member.userId));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('member_data_erased'.tr())));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('error_occurred'.tr())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('banned_members'.tr())),
      body: SafeArea(
        child: PageBody(maxWidth: 640, scrollable: false, child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_hasError) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'error_occurred'.tr(),
        action: TextButton(onPressed: _load, child: Text('retry'.tr())),
      );
    }

    if (_members.isEmpty) {
      return EmptyState(
        icon: Icons.verified_user_outlined,
        title: 'no_banned_members'.tr(),
        body: 'no_banned_members_body'.tr(),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: Spacing.md),
      itemCount: _members.length,
      separatorBuilder: (_, _) => const SizedBox(height: Spacing.sm),
      itemBuilder: (context, index) {
        final member = _members[index];
        final theme = Theme.of(context);

        return ContentCard(
          accent: theme.colorScheme.error,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name.isEmpty ? member.userId : member.name,
                      style: theme.textTheme.titleSmall,
                    ),
                    if (member.bannedAt case final bannedAt?) ...[
                      const SizedBox(height: 2),
                      Text(
                        'banned_on'.tr(
                          namedArgs: {
                            'date': DateFormat.yMMMd().format(bannedAt),
                          },
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _unban(member),
                child: Text('unban_user'.tr()),
              ),
              IconButton(
                tooltip: 'erase_member_data'.tr(),
                onPressed: () => _erase(member),
                icon: Icon(
                  Icons.delete_forever_outlined,
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WarningDialog extends StatelessWidget {
  const _WarningDialog({
    required this.title,
    required this.body,
    required this.confirmLabel,
  });

  final String title;
  final String body;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      icon: Icon(Icons.warning_amber_rounded, color: scheme.error),
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('cancel'.tr()),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}

class _CountdownDialog extends StatefulWidget {
  const _CountdownDialog({required this.name});

  final String name;

  @override
  State<_CountdownDialog> createState() => _CountdownDialogState();
}

class _CountdownDialogState extends State<_CountdownDialog> {
  static const _seconds = 60;

  Timer? _timer;
  int _remaining = _seconds;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining <= 0) {
        timer.cancel();

        Navigator.of(context).pop(true);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AlertDialog(
      icon: Icon(Icons.timer_outlined, color: scheme.error),
      title: Text('erasing_in'.tr()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$_remaining',
            style: theme.textTheme.displayMedium?.copyWith(
              color: scheme.error,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Spacing.md),
          Text(
            'erase_countdown_body'.tr(namedArgs: {'name': widget.name}),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: Spacing.md),
          LinearProgressIndicator(
            value: _remaining / _seconds,
            color: scheme.error,
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('keep_the_data'.tr()),
        ),
      ],
    );
  }
}
