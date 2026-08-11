import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/layout/page_body.dart';
import 'package:echomeet/core/membership/ownership_transfer_service.dart';
import 'package:echomeet/core/widgets/feature_kit.dart';
import 'package:echomeet/settings/settings_kit.dart';
import 'package:flutter/material.dart';

typedef OwnershipTargetsLoader =
    Future<List<OwnershipTransferTarget>> Function();

String ownershipTransferFailureKey(
  OwnershipTransferFailure failure,
) => switch (failure) {
  OwnershipTransferFailure.invalidCredential => 'invalid_current_password',
  OwnershipTransferFailure.recentLoginRequired =>
    'ownership_transfer_recent_login',
  OwnershipTransferFailure.accountUnavailable =>
    'ownership_transfer_account_unavailable',
  OwnershipTransferFailure.invalidTarget ||
  OwnershipTransferFailure.targetUnavailable ||
  OwnershipTransferFailure.targetAccountUnavailable =>
    'ownership_transfer_target_unavailable',
  OwnershipTransferFailure.accountDeleting =>
    'ownership_transfer_account_deleting',
  OwnershipTransferFailure.ownerRequired => 'ownership_transfer_owner_required',
  OwnershipTransferFailure.notRecipient ||
  OwnershipTransferFailure.notRequested => 'ownership_transfer_not_available',
  OwnershipTransferFailure.expired => 'ownership_transfer_expired',
  OwnershipTransferFailure.companyClosing =>
    'ownership_transfer_company_closing',
  OwnershipTransferFailure.stateInvalid => 'ownership_transfer_state_invalid',
  OwnershipTransferFailure.unavailable => 'ownership_transfer_unavailable',
};

Future<String?> promptForOwnershipPassword({
  required BuildContext context,
  required String title,
  required String body,
  required String actionLabel,
}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(body),
          const SizedBox(height: Spacing.lg),
          TextField(
            controller: controller,
            obscureText: true,
            autofocus: true,
            autofillHints: const [AutofillHints.password],
            decoration: InputDecoration(
              labelText: 'current_password'.tr(),
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text('cancel'.tr()),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(controller.text),
          child: Text(actionLabel),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}

class OwnershipTransferPage extends StatefulWidget {
  const OwnershipTransferPage({
    super.key,
    required this.companyId,
    required this.currentUid,
    this.firestore,
    this.service,
    this.targetsLoader,
  });

  final String companyId;
  final String currentUid;
  final FirebaseFirestore? firestore;
  final OwnershipTransferService? service;
  final OwnershipTargetsLoader? targetsLoader;

  @override
  State<OwnershipTransferPage> createState() => _OwnershipTransferPageState();
}

class _OwnershipTransferPageState extends State<OwnershipTransferPage> {
  late Future<List<OwnershipTransferTarget>> _targets;
  bool _saving = false;

  OwnershipTransferService get _service =>
      widget.service ?? OwnershipTransferService();

  @override
  void initState() {
    super.initState();
    _targets = _loadTargets();
  }

  Future<List<OwnershipTransferTarget>> _loadTargets() async {
    final providedLoader = widget.targetsLoader;
    if (providedLoader != null) return providedLoader();

    final snapshot = await (widget.firestore ?? FirebaseFirestore.instance)
        .collection('memberDirectory')
        .where('companyId', isEqualTo: widget.companyId)
        .get();
    final targets = <OwnershipTransferTarget>[];
    for (final member in snapshot.docs) {
      final target = OwnershipTransferTarget.fromMemberDirectory(
        uid: member.id,
        data: member.data(),
        companyId: widget.companyId,
        currentUid: widget.currentUid,
      );
      if (target != null) targets.add(target);
    }
    targets.sort((left, right) {
      final byName = left.fullName.toLowerCase().compareTo(
        right.fullName.toLowerCase(),
      );
      return byName != 0 ? byName : left.uid.compareTo(right.uid);
    });
    return List.unmodifiable(targets);
  }

  void _retry() {
    setState(() => _targets = _loadTargets());
  }

  Future<void> _select(OwnershipTransferTarget target) async {
    if (_saving) return;
    final password = await promptForOwnershipPassword(
      context: context,
      title: 'transfer_ownership'.tr(),
      body: 'transfer_ownership_confirm'.tr(
        namedArgs: {'member': target.fullName},
      ),
      actionLabel: 'transfer_ownership'.tr(),
    );
    if (password == null || !mounted) return;

    setState(() => _saving = true);
    try {
      final receipt = await _service.request(
        targetUid: target.uid,
        password: password,
      );
      if (!mounted) return;
      Navigator.of(context).pop(receipt);
    } on OwnershipTransferException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ownershipTransferFailureKey(error.failure).tr()),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ownership_transfer_unavailable'.tr())),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('transfer_ownership'.tr())),
      body: SafeArea(
        child: PageBody(
          maxWidth: 640,
          child: FutureBuilder<List<OwnershipTransferTarget>>(
            future: _targets,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(Spacing.xxl),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'error_occurred'.tr(),
                  action: TextButton(
                    onPressed: _retry,
                    child: Text('retry'.tr()),
                  ),
                );
              }

              final targets = snapshot.data ?? const [];
              if (targets.isEmpty) {
                return EmptyState(
                  icon: Icons.people_outline_rounded,
                  title: 'ownership_transfer_no_members'.tr(),
                  body: 'transfer_ownership_hint'.tr(),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'transfer_ownership_warning'.tr(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  SettingsGroup(
                    title: 'transfer_ownership_members'.tr(),
                    children: [
                      for (final target in targets)
                        SettingsTile(
                          icon: Icons.person_outline_rounded,
                          title: target.fullName,
                          subtitle: 'role_${target.role}'.tr(),
                          onTap: _saving ? null : () => _select(target),
                        ),
                    ],
                  ),
                  if (_saving) ...[
                    const SizedBox(height: Spacing.lg),
                    const LinearProgressIndicator(),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
