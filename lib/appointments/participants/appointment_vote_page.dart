import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/appointments/appointment_data.dart';
import 'package:echomeet/appointments/edit/appointment_edit.dart';
import 'package:echomeet/appointments/firebase/appointment_services.dart';
import 'package:echomeet/appointments/participants/vote_slot_card.dart';
import 'package:echomeet/appointments/utilities/vote_tally.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/layout/page_body.dart';
import 'package:echomeet/core/theme/app_colors.dart';
import 'package:echomeet/core/time/deadline.dart';
import 'package:echomeet/core/widgets/feature_kit.dart';
import 'package:echomeet/core/widgets/status_pill.dart';
import 'package:echomeet/core/widgets/wizard_scaffold.dart';
import 'package:echomeet/utilities/reusable_widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AppointmentVotePage extends StatefulWidget {
  const AppointmentVotePage({
    super.key,
    required this.appointment,
    required this.isAdmin,
  });

  final Appointment appointment;
  final bool isAdmin;

  @override
  State<AppointmentVotePage> createState() => _AppointmentVotePageState();
}

class _AppointmentVotePageState extends State<AppointmentVotePage> {
  final _service = AppointmentService();
  final _userId = FirebaseAuth.instance.currentUser?.uid ?? '';

  List<AppointmentParticipants> _votes = [];

  final Map<DateTime, VoteStatus> _pending = {};

  bool _loading = true;
  bool _saving = false;
  String? _error;

  Appointment get _appointment => widget.appointment;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final votes = await _service.fetchAllParticipants(
        _appointment.appointmentId,
      );
      if (!mounted) return;
      setState(() {
        _votes = votes;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Deadline get _deadline => deadlineFor(
    _appointment.expirationDate,
    now: DateTime.now(),
    openedAt: _appointment.creationDate,
  );

  TimeSlot? get _confirmedSlot =>
      _appointment.availableTimeSlots.where((s) => s.isConfirmed).firstOrNull;

  bool get _canVote => !_deadline.isPassed && _confirmedSlot == null;

  VoteStatus? _statusFor(TimeSlot slot) =>
      _pending[slot.start] ?? votesOf(_userId, _votes)[slot.start];

  void _choose(TimeSlot slot, VoteStatus status) {
    setState(() {
      if (_statusFor(slot) == status) {
        _pending[slot.start] = VoteStatus.maybe;
      } else {
        _pending[slot.start] = status;
      }
    });
  }

  Future<void> _submit() async {
    if (_pending.isEmpty) {
      Navigator.pop(context);
      return;
    }

    setState(() => _saving = true);

    try {
      final name = await _service.fetchUserNameById(_userId);

      for (final entry in _pending.entries) {
        final slot = _appointment.availableTimeSlots.firstWhere(
          (s) => s.start == entry.key,
        );
        await _service.updateParticipantStatus(
          _userId,
          _appointment.appointmentId,
          name,
          slot.start,
          slot,
          entry.value.wireName,
        );
      }

      await _service.registerParticipation(_appointment.appointmentId, _userId);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      UIUtils.showSnackBar(context, 'error_occurred'.tr());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirm(TimeSlot slot) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('confirm_this_time'.tr()),
        content: Text(
          'confirm_this_time_body'.tr(
            namedArgs: {
              'time':
                  '${DateFormat.yMMMMEEEEd().format(slot.start)}, '
                  '${DateFormat.jm().format(slot.start)}',
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('confirm'.tr()),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await _service.confirmTimeSlot(_appointment.appointmentId, slot);
      if (!mounted) return;
      setState(() {
        for (final s in _appointment.availableTimeSlots) {
          s.isConfirmed = s.start == slot.start;
        }
      });
    } catch (_) {
      if (!mounted) return;
      UIUtils.showSnackBar(context, 'error_occurred'.tr());
    }
  }

  @override
  Widget build(BuildContext context) {
    final slots = _appointment.availableTimeSlots;
    final tally = tallyVotes(slots, _votes);

    return Scaffold(
      appBar: AppBar(
        title: Text(_appointment.title, overflow: TextOverflow.ellipsis),
        actions: [
          if (widget.isAdmin)
            IconButton(
              tooltip: 'appointment_edit'.tr(),
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AppointmentEditPage(
                      appointment: _appointment,
                      userName: '',
                      timeSlot: slots.first,
                    ),
                  ),
                );
                if (mounted) _load();
              },
            ),
        ],
      ),
      body: SafeArea(child: _buildBody(slots, tally)),
      bottomNavigationBar: _canVote && !_loading && _error == null
          ? WizardActionBar(
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _pending.isEmpty
                            ? 'done'.tr()
                            : 'save_votes'.tr(
                                namedArgs: {'count': '${_pending.length}'},
                              ),
                      ),
              ),
            )
          : null,
    );
  }

  Widget _buildBody(List<TimeSlot> slots, AppointmentTally tally) {
    if (_loading) {
      return const Center(child: CustomLoadingWidget(loadingText: 'loading'));
    }

    if (_error case final error?) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'error_occurred'.tr(),
        body: error,
        action: TextButton(onPressed: _load, child: Text('retry'.tr())),
      );
    }

    final confirmed = _confirmedSlot;
    final voters = _votes.map((vote) => vote.userId).toSet().length;

    return PageBody(
      maxWidth: 640,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            appointment: _appointment,
            deadline: _deadline,
            voters: voters,
            confirmed: confirmed,
          ),
          const SizedBox(height: Spacing.xl),
          if (!_canVote && confirmed == null)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.md),
              child: _Notice(text: 'voting_has_closed'.tr()),
            ),
          for (final slot in slots)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.md),
              child: VoteSlotCard(
                slot: slot,
                tally: tally.forSlot(slot),
                myStatus: _statusFor(slot),
                isLeader:
                    tally.leader != null &&
                    tally.leader!.start == slot.start &&
                    confirmed == null,
                isTied: tally.isTied,
                enabled: _canVote,
                onChoose: (status) => _choose(slot, status),
                onShowVoters: () => _showVoters(slot),
                onConfirm: widget.isAdmin && confirmed == null
                    ? () => _confirm(slot)
                    : null,
              ),
            ),
          const SizedBox(height: Spacing.xxl),
        ],
      ),
    );
  }

  void _showVoters(TimeSlot slot) {
    final forSlot = _votes
        .where((vote) => vote.timeSlot.start == slot.start)
        .toList();

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => _VoterSheet(slot: slot, votes: forSlot),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.appointment,
    required this.deadline,
    required this.voters,
    required this.confirmed,
  });

  final Appointment appointment;
  final Deadline deadline;
  final int voters;
  final TimeSlot? confirmed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final app = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (appointment.description.isNotEmpty) ...[
          Text(
            appointment.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.md),
        ],
        Wrap(
          spacing: Spacing.sm,
          runSpacing: Spacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (confirmed != null)
              StatusPill(
                label: 'time_slot_confirmed'.tr(),
                tone: StatusTone.positive,
                icon: Icons.event_available_rounded,
              )
            else
              StatusPill(
                label: deadline.labelKey.tr(
                  namedArgs: {'count': '${deadline.days}'},
                ),
                tone: deadline.isPassed
                    ? StatusTone.neutral
                    : deadline.urgency == DeadlineUrgency.imminent
                    ? StatusTone.caution
                    : StatusTone.info,
                icon: Icons.how_to_vote_rounded,
              ),
            MetaChip(
              icon: Icons.group_outlined,
              label: 'participants_count'.tr(namedArgs: {'count': '$voters'}),
            ),
          ],
        ),
        if (confirmed != null) ...[
          const SizedBox(height: Spacing.md),
          Container(
            padding: const EdgeInsets.all(Spacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: app.success.withValues(alpha: 0.12),
              border: Border.all(color: app.success.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: app.success, size: 20),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Text(
                    '${DateFormat.yMMMMEEEEd().format(confirmed!.start)} · '
                    '${DateFormat.jm().format(confirmed!.start)}',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 18,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: Spacing.md),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

class _VoterSheet extends StatelessWidget {
  const _VoterSheet({required this.slot, required this.votes});

  final TimeSlot slot;
  final List<AppointmentParticipants> votes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final groups = <VoteStatus, List<AppointmentParticipants>>{};
    for (final vote in votes) {
      final status = VoteStatus.fromWire(vote.status);
      if (status != null) (groups[status] ??= []).add(vote);
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.xl,
          0,
          Spacing.xl,
          Spacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${DateFormat.MMMMEEEEd().format(slot.start)} · '
              '${DateFormat.jm().format(slot.start)}',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: Spacing.lg),
            if (votes.isEmpty)
              Text(
                'nobody_voted_yet'.tr(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            for (final status in VoteStatus.values)
              if (groups[status]?.isNotEmpty ?? false) ...[
                SectionLabel(
                  label: voteLabelKey(status).tr(),
                  count: groups[status]!.length,
                ),
                for (final vote in groups[status]!)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
                    child: Row(
                      children: [
                        Icon(
                          voteIcon(status),
                          size: 16,
                          color: voteColor(context, status),
                        ),
                        const SizedBox(width: Spacing.md),
                        Text(vote.userName, style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
              ],
          ],
        ),
      ),
    );
  }
}
