import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/appointments/appointment_data.dart';
import 'package:echomeet/appointments/firebase/appointment_services.dart';
import 'package:echomeet/appointments/participants/appointment_participants_pdf.dart';
import 'package:echomeet/appointments/participants/participant_overview.dart';
import 'package:echomeet/appointments/participants/vote_slot_card.dart';
import 'package:echomeet/appointments/utilities/vote_tally.dart';
import 'package:echomeet/appointments/widgets/appointment_time_text.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/layout/page_body.dart';
import 'package:echomeet/core/theme/app_theme.dart';
import 'package:echomeet/core/widgets/feature_kit.dart';
import 'package:echomeet/utilities/reusable_widgets.dart';
import 'package:flutter/material.dart';

class AppointmentParticipantsPage extends StatefulWidget {
  const AppointmentParticipantsPage({super.key, required this.appointment});

  final Appointment appointment;

  @override
  State<AppointmentParticipantsPage> createState() =>
      _AppointmentParticipantsPageState();
}

class _AppointmentParticipantsPageState
    extends State<AppointmentParticipantsPage> {
  final _service = AppointmentService();
  final _searchController = TextEditingController();

  List<AppointmentParticipants>? _votes;
  Map<String, String>? _memberNames;
  bool _failed = false;

  StreamSubscription<List<AppointmentParticipants>>? _votesSubscription;
  StreamSubscription<Map<String, String>>? _membersSubscription;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
    _listen();
  }

  @override
  void dispose() {
    _searchController.dispose();
    unawaited(_votesSubscription?.cancel());
    unawaited(_membersSubscription?.cancel());
    super.dispose();
  }

  void _listen() {
    setState(() {
      _failed = false;
      _votes = null;
      _memberNames = null;
    });

    _votesSubscription = _service
        .watchParticipants(widget.appointment.appointmentId)
        .listen(
          (votes) {
            if (mounted) setState(() => _votes = votes);
          },
          onError: (Object _) {
            if (mounted) setState(() => _failed = true);
          },
        );

    _membersSubscription = _service
        .watchCompanyMemberNames(widget.appointment.companyId ?? '')
        .listen(
          (names) {
            if (mounted) setState(() => _memberNames = names);
          },
          onError: (Object _) {
            if (mounted) setState(() => _failed = true);
          },
        );
  }

  Future<void> _restart() async {
    final votesSubscription = _votesSubscription;
    final membersSubscription = _membersSubscription;
    _votesSubscription = null;
    _membersSubscription = null;
    await Future.wait<void>([
      if (votesSubscription != null) votesSubscription.cancel(),
      if (membersSubscription != null) membersSubscription.cancel(),
    ]);
    if (mounted) _listen();
  }

  ParticipantOverview? get _overview {
    final votes = _votes;
    final memberNames = _memberNames;
    if (votes == null || memberNames == null) return null;
    return buildParticipantOverview(
      slots: widget.appointment.availableTimeSlots,
      votes: votes,
      memberNames: memberNames,
      unknownName: 'unknown'.tr(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final overview = _overview;

    return Scaffold(
      appBar: AppBar(
        title: Text('all_participants'.tr()),
        actions: [
          if (overview == null)
            const IconButton(
              icon: Icon(Icons.picture_as_pdf_outlined),
              onPressed: null,
            )
          else
            PopupMenuButton<ParticipantExportScope>(
              tooltip: 'export_participants'.tr(),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              onSelected: (scope) => _export(overview, scope),
              itemBuilder: (context) => [
                if (widget.appointment.confirmedSlotId != null)
                  PopupMenuItem(
                    value: ParticipantExportScope.confirmedOnly,
                    child: _ExportChoice(
                      icon: Icons.event_available_outlined,
                      title: 'export_confirmed_time'.tr(),
                      hint: 'export_confirmed_time_hint'.tr(),
                    ),
                  ),
                PopupMenuItem(
                  value: ParticipantExportScope.allTimes,
                  child: _ExportChoice(
                    icon: Icons.calendar_month_outlined,
                    title: 'export_all_times'.tr(),
                    hint: 'export_all_times_hint'.tr(),
                  ),
                ),
              ],
            ),
          const SizedBox(width: Spacing.xs),
        ],
      ),
      body: SafeArea(child: _buildBody(overview)),
    );
  }

  void _export(ParticipantOverview overview, ParticipantExportScope scope) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AppointmentParticipantsPdf(
          appointment: widget.appointment,
          overview: overview,
          scope: scope,
        ),
      ),
    );
  }

  List<ParticipantRow> _matching(ParticipantOverview overview) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return overview.rows;
    return overview.rows
        .where((row) => row.name.toLowerCase().contains(query))
        .toList();
  }

  Widget _buildBody(ParticipantOverview? overview) {
    if (_failed) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'error_occurred'.tr(),
        action: TextButton(
          onPressed: () => unawaited(_restart()),
          child: Text('retry'.tr()),
        ),
      );
    }

    if (overview == null) {
      return const Center(child: CustomLoadingWidget(loadingText: 'loading'));
    }

    if (overview.rows.isEmpty) {
      return EmptyState(
        icon: Icons.group_outlined,
        title: 'nobody_voted_yet'.tr(),
      );
    }

    final slots = widget.appointment.availableTimeSlots;

    return PageBody(
      maxWidth: 720,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ResponseSummary(overview: overview),
          for (final slot in slots)
            _SlotSummary(
              slot: slot,
              zoneId: widget.appointment.zoneId,
              totals: overview.totalsBySlotId[slot.slotId],
            ),
          SectionLabel(label: 'participants'.tr(), count: overview.rows.length),
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.sm),
            child: SearchPill(
              controller: _searchController,
              hint: 'search_participants'.tr(),
            ),
          ),
          if (_matching(overview).isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.xl),
              child: Text(
                'no_search_results'.tr(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final row in _matching(overview))
              Padding(
                padding: const EdgeInsets.only(bottom: Spacing.sm),
                child: _ParticipantCard(row: row, slots: slots),
              ),
          const SizedBox(height: Spacing.xxl),
        ],
      ),
    );
  }
}

class _ResponseSummary extends StatelessWidget {
  const _ResponseSummary({required this.overview});

  final ParticipantOverview overview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final total = overview.rows.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'participants_responded'.tr(
            namedArgs: {
              'responded': '${overview.respondedCount}',
              'total': '$total',
            },
          ),
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: Spacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 6,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (overview.respondedCount > 0)
                  Expanded(
                    flex: overview.respondedCount,
                    child: ColoredBox(color: scheme.primary),
                  ),
                if (overview.awaitingCount > 0)
                  Expanded(
                    flex: overview.awaitingCount,
                    child: ColoredBox(
                      color: scheme.outlineVariant.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (overview.awaitingCount > 0) ...[
          const SizedBox(height: Spacing.sm),
          Text(
            'participants_awaiting'.tr(
              namedArgs: {'count': '${overview.awaitingCount}'},
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _SlotSummary extends StatelessWidget {
  const _SlotSummary({
    required this.slot,
    required this.zoneId,
    required this.totals,
  });

  final TimeSlot slot;
  final String zoneId;
  final SlotTotals? totals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final counts = totals;

    return Padding(
      padding: const EdgeInsets.only(top: Spacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (slot.isConfirmed)
            Padding(
              padding: const EdgeInsets.only(right: Spacing.sm, top: 2),
              child: Icon(
                Icons.event_available_rounded,
                size: 16,
                color: scheme.primary,
              ),
            ),
          Expanded(
            child: AppointmentTimeText(
              startAt: slot.startAt,
              endAt: slot.endAt,
              zoneId: zoneId,
              style: theme.textTheme.bodyMedium,
              secondaryStyle: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          if (counts != null) ...[
            const SizedBox(width: Spacing.md),
            for (final status in VoteStatus.values)
              Padding(
                padding: const EdgeInsets.only(left: Spacing.sm),
                child: _CountChip(
                  status: status,
                  count: switch (status) {
                    VoteStatus.yes => counts.yes,
                    VoteStatus.maybe => counts.maybe,
                    VoteStatus.no => counts.no,
                  },
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.status, required this.count});

  final VoteStatus status;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = voteColor(context, status);

    return Semantics(
      label: '${voteLabelKey(status).tr()}: $count',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(voteIcon(status), size: 13, color: color),
          const SizedBox(width: 3),
          Text(
            '$count',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ParticipantCard extends StatelessWidget {
  const _ParticipantCard({required this.row, required this.slots});

  final ParticipantRow row;
  final List<TimeSlot> slots;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ContentCard(
      muted: !row.hasResponded,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.name,
                  style: theme.textTheme.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!row.isCurrentMember) ...[
                  const SizedBox(height: 2),
                  Text(
                    'former_member'.tr(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ] else if (!row.hasResponded) ...[
                  const SizedBox(height: 2),
                  Text(
                    'has_not_answered'.tr(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (row.hasResponded) ...[
            const SizedBox(width: Spacing.md),

            Wrap(
              spacing: Spacing.xs,
              runSpacing: Spacing.xs,
              children: [
                for (final slot in slots)
                  _StatusMark(status: row.statusFor(slot.slotId)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusMark extends StatelessWidget {
  const _StatusMark({required this.status});

  final VoteStatus? status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = status;

    if (current == null) {
      return Semantics(
        label: 'has_not_answered'.tr(),
        child: Container(
          height: 26,
          width: 26,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.sm),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: Icon(
            Icons.remove_rounded,
            size: 13,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    final color = voteColor(context, current);

    return Semantics(
      label: voteLabelKey(current).tr(),
      child: Container(
        height: 26,
        width: 26,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.sm),
          color: color.withValues(alpha: 0.16),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Icon(voteIcon(current), size: 14, color: color),
      ),
    );
  }
}

class _ExportChoice extends StatelessWidget {
  const _ExportChoice({
    required this.icon,
    required this.title,
    required this.hint,
  });

  final IconData icon;
  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: Spacing.md),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: theme.textTheme.bodyMedium),
            Text(
              hint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
