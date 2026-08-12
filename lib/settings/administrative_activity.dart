import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/layout/page_body.dart';
import 'package:echomeet/core/membership/company_activity_service.dart';
import 'package:echomeet/core/widgets/feature_kit.dart';
import 'package:echomeet/utilities/reusable_widgets.dart';
import 'package:flutter/material.dart';

class AdministrativeActivityPage extends StatefulWidget {
  const AdministrativeActivityPage({
    super.key,
    required this.companyId,
    this.service,
  });

  final String companyId;
  final CompanyActivityService? service;

  @override
  State<AdministrativeActivityPage> createState() =>
      _AdministrativeActivityPageState();
}

class _AdministrativeActivityPageState
    extends State<AdministrativeActivityPage> {
  late final CompanyActivityService _service;
  late final Stream<Map<String, String>> _memberNames;

  List<CompanyActivity> _entries = const [];
  DocumentSnapshot<Map<String, dynamic>>? _cursor;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? CompanyActivityService();
    _memberNames = _service.watchMemberNames(widget.companyId);
    _loadFirstPage();
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final page = await _service.loadPage(widget.companyId);
      if (!mounted) return;
      setState(() {
        _entries = page.entries;
        _cursor = page.cursor;
        _hasMore = page.hasMore;
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

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _cursor == null) return;
    setState(() => _loadingMore = true);
    try {
      final page = await _service.loadPage(widget.companyId, after: _cursor);
      if (!mounted) return;
      setState(() {
        _entries = List.unmodifiable([..._entries, ...page.entries]);
        _cursor = page.cursor;
        _hasMore = page.hasMore;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('error_occurred'.tr())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('activity_log'.tr())),
      body: SafeArea(
        child: PageBody(maxWidth: 640, scrollable: false, child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CustomLoadingWidget(loadingText: 'loading'));
    }
    if (_hasError) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'error_occurred'.tr(),
        action: TextButton(
          onPressed: _loadFirstPage,
          child: Text('retry'.tr()),
        ),
      );
    }

    if (_entries.isEmpty && !_hasMore) {
      return EmptyState(
        icon: Icons.history_rounded,
        title: 'activity_log_empty'.tr(),
      );
    }

    return StreamBuilder<Map<String, String>>(
      stream: _memberNames,
      initialData: const {},
      builder: (context, snapshot) {
        final names = snapshot.data ?? const <String, String>{};
        return RefreshIndicator(
          onRefresh: _loadFirstPage,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: Spacing.md),
            itemCount: _entries.length + (_hasMore ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: Spacing.sm),
            itemBuilder: (context, index) {
              if (index == _entries.length) {
                return Center(
                  child: TextButton(
                    onPressed: _loadingMore ? null : _loadMore,
                    child: _loadingMore
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text('activity_log_load_more'.tr()),
                  ),
                );
              }
              return _ActivityRow(entry: _entries[index], names: names);
            },
          ),
        );
      },
    );
  }
}

String companyActivityDescription(
  CompanyActivity entry,
  Map<String, String> names,
) {
  String name(String uid) =>
      safeActivityMemberName(names[uid]) ?? 'activity_member_unavailable'.tr();
  String role(Object? value) {
    final role = value is String ? value : '';
    if (const {'user', 'moderator', 'admin', 'superadmin'}.contains(role)) {
      return 'role_$role'.tr();
    }
    return 'unknown'.tr();
  }

  String joinPolicy(Object? value) => switch (value) {
    'open' => 'activity_join_policy_open'.tr(),
    'approval' => 'activity_join_policy_approval'.tr(),
    _ => 'unknown'.tr(),
  };

  final actor = name(entry.actorUid);
  final targetUid = entry.targetUid;
  final target = targetUid == null ? '' : name(targetUid);
  final arguments = {'actor': actor, 'target': target};
  final entity = entry.entity;
  final title = entity == null || entity.title.isEmpty
      ? 'activity_untitled'.tr()
      : entity.title;

  return switch (entry.action) {
    'member.approved' => 'activity_action_member_approved'.tr(
      namedArgs: arguments,
    ),
    'member.role_changed' => 'activity_action_member_role_changed'.tr(
      namedArgs: {
        ...arguments,
        'from': role(entry.before['role']),
        'to': role(entry.after['role']),
      },
    ),
    'member.banned' => 'activity_action_member_banned'.tr(namedArgs: arguments),
    'member.unbanned' => 'activity_action_member_unbanned'.tr(
      namedArgs: arguments,
    ),
    'member.removed' => 'activity_action_member_removed'.tr(
      namedArgs: arguments,
    ),
    'member.company_data_erased' => 'activity_action_member_data_erased'.tr(
      namedArgs: arguments,
    ),
    'company.join_policy_changed' => 'activity_action_join_policy_changed'.tr(
      namedArgs: {
        'actor': actor,
        'policy': joinPolicy(entry.after['joinPolicy']),
      },
    ),
    'company.deletion_scheduled' => 'activity_action_deletion_scheduled'.tr(
      namedArgs: arguments,
    ),
    'company.deletion_cancelled' => 'activity_action_deletion_cancelled'.tr(
      namedArgs: arguments,
    ),
    'company.created' => 'activity_action_company_created'.tr(
      namedArgs: arguments,
    ),
    'company.ownership_transferred' =>
      'activity_action_ownership_transferred'.tr(namedArgs: arguments),
    'account.email_changed' => 'activity_action_email_changed'.tr(
      namedArgs: arguments,
    ),
    'survey.created' =>
      (entity?.type == 'test'
              ? 'activity_action_test_created'
              : 'activity_action_survey_created')
          .tr(namedArgs: {'actor': actor, 'title': title}),
    'survey.deleted' =>
      (entity?.type == 'test'
              ? 'activity_action_test_deleted'
              : 'activity_action_survey_deleted')
          .tr(namedArgs: {'actor': actor, 'title': title}),
    'appointment.created' => 'activity_action_appointment_created'.tr(
      namedArgs: {'actor': actor, 'title': title},
    ),
    'appointment.updated' => 'activity_action_appointment_updated'.tr(
      namedArgs: {'actor': actor, 'title': title},
    ),
    'appointment.deleted' => 'activity_action_appointment_deleted'.tr(
      namedArgs: {'actor': actor, 'title': title},
    ),
    'appointment.slot_confirmed' =>
      'activity_action_appointment_slot_confirmed'.tr(
        namedArgs: {
          'actor': actor,
          'title': title,
          'time': DateFormat.MMMEd().add_jm().format(
            (entry.after['confirmedStartAt'] as Timestamp).toDate().toLocal(),
          ),
        },
      ),
    _ => 'activity_action_unknown'.tr(namedArgs: arguments),
  };
}

IconData companyActivityIcon(CompanyActivity entry) => switch (entry.action) {
  'member.approved' => Icons.person_add_alt_1_rounded,
  'member.role_changed' => Icons.admin_panel_settings_outlined,
  'member.banned' => Icons.block_rounded,
  'member.unbanned' => Icons.lock_open_rounded,
  'member.removed' => Icons.person_remove_outlined,
  'member.company_data_erased' => Icons.delete_sweep_outlined,
  'company.join_policy_changed' => Icons.door_front_door_outlined,
  'company.deletion_scheduled' => Icons.domain_disabled_outlined,
  'company.deletion_cancelled' => Icons.undo_rounded,
  'company.created' => Icons.add_business_rounded,
  'company.ownership_transferred' => Icons.swap_horiz_rounded,
  'account.email_changed' => Icons.alternate_email_rounded,
  'survey.created' =>
    entry.entity?.type == 'test'
        ? Icons.workspace_premium_outlined
        : Icons.poll_outlined,
  'survey.deleted' => Icons.delete_outline_rounded,
  'appointment.created' => Icons.event_available_outlined,
  'appointment.updated' => Icons.edit_calendar_outlined,
  'appointment.deleted' => Icons.event_busy_outlined,
  'appointment.slot_confirmed' => Icons.task_alt_rounded,
  _ => Icons.history_rounded,
};

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.entry, required this.names});

  final CompanyActivity entry;
  final Map<String, String> names;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ContentCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primary.withValues(alpha: 0.12),
            ),
            child: Icon(
              companyActivityIcon(entry),
              size: 18,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  companyActivityDescription(entry, names),
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat.yMMMd().add_jm().format(
                    entry.occurredAt.toLocal(),
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
