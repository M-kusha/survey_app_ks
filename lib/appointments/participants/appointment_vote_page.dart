import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/appointments/appointment_data.dart';
import 'package:echomeet/appointments/calendar/appointment_ics.dart';
import 'package:echomeet/core/files/text_download.dart';
import 'package:echomeet/appointments/edit/appointment_edit.dart';
import 'package:echomeet/appointments/firebase/appointment_services.dart';
import 'package:echomeet/appointments/participants/appointment_participants_page.dart';
import 'package:echomeet/appointments/participants/vote_slot_card.dart';
import 'package:echomeet/appointments/utilities/vote_tally.dart';
import 'package:echomeet/appointments/widgets/appointment_time_text.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/layout/page_body.dart';
import 'package:echomeet/core/theme/app_colors.dart';
import 'package:echomeet/core/time/deadline.dart';
import 'package:echomeet/core/time/appointment_time.dart';
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

  final Map<SlotKey, VoteStatus> _pending = {};

  bool _loading = true;
  bool _saving = false;
  String? _error;
  Timer? _deadlineTimer;
  StreamSubscription<Appointment?>? _appointmentSubscription;
  StreamSubscription<List<AppointmentParticipants>>? _votesSubscription;
  var _streamGeneration = 0;
  var _appointmentSeen = false;
  var _votesSeen = false;
  var _appointmentDeleted = false;
  String? _appointmentError;
  String? _votesError;

  late Appointment _appointment;

  @override
  void initState() {
    super.initState();
    _appointment = widget.appointment;
    unawaited(_load());
  }

  @override
  void dispose() {
    _streamGeneration++;
    _deadlineTimer?.cancel();
    final appointmentSubscription = _appointmentSubscription;
    final votesSubscription = _votesSubscription;
    if (appointmentSubscription != null) {
      unawaited(appointmentSubscription.cancel());
    }
    if (votesSubscription != null) {
      unawaited(votesSubscription.cancel());
    }
    super.dispose();
  }

  void _scheduleDeadlineRefresh() {
    _deadlineTimer?.cancel();
    final remaining = _appointment.expirationDate.difference(DateTime.now());
    if (remaining <= Duration.zero) return;

    _deadlineTimer = Timer(remaining + const Duration(milliseconds: 10), () {
      if (!mounted) return;
      setState(_pending.clear);
    });
  }

  Future<void> _load() async {
    final generation = ++_streamGeneration;
    final previousAppointmentSubscription = _appointmentSubscription;
    final previousVotesSubscription = _votesSubscription;
    _appointmentSubscription = null;
    _votesSubscription = null;
    await Future.wait<void>([
      if (previousAppointmentSubscription != null)
        previousAppointmentSubscription.cancel(),
      if (previousVotesSubscription != null) previousVotesSubscription.cancel(),
    ]);
    if (!mounted || generation != _streamGeneration) return;

    _scheduleDeadlineRefresh();
    setState(() {
      _loading = true;
      _error = null;
      _appointmentSeen = false;
      _votesSeen = false;
      _appointmentError = null;
      _votesError = null;
    });

    final appointmentId = _appointment.appointmentId;
    _appointmentSubscription = _service
        .watchAppointment(appointmentId)
        .listen(
          (appointment) {
            if (!mounted || generation != _streamGeneration) return;
            if (appointment == null) {
              _deadlineTimer?.cancel();
              setState(() {
                _appointmentSeen = true;
                _appointmentDeleted = true;
                _appointmentError = 'appointment_deleted'.tr();
                _pending.clear();
                _applyLiveState();
              });
              return;
            }

            setState(() {
              _appointment = appointment;
              _appointmentSeen = true;
              _appointmentDeleted = false;
              _appointmentError = null;
              final availableSlots = appointment.availableTimeSlots
                  .map(slotKeyOf)
                  .toSet();
              _pending.removeWhere((slot, _) => !availableSlots.contains(slot));
              final confirmed =
                  appointment.confirmedTimeSlots.isNotEmpty ||
                  appointment.availableTimeSlots.any(
                    (slot) => slot.isConfirmed,
                  );
              if (confirmed ||
                  !appointment.expirationDate.isAfter(DateTime.now())) {
                _pending.clear();
              }
              _applyLiveState();
            });
            _scheduleDeadlineRefresh();
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!mounted || generation != _streamGeneration) return;
            setState(() {
              _appointmentSeen = true;
              _appointmentError = '$error';
              _applyLiveState();
            });
          },
        );
    _votesSubscription = _service
        .watchParticipants(appointmentId)
        .listen(
          (votes) {
            if (!mounted || generation != _streamGeneration) return;
            setState(() {
              _votes = votes;
              _votesSeen = true;
              _votesError = null;
              _applyLiveState();
            });
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!mounted || generation != _streamGeneration) return;
            setState(() {
              _votesSeen = true;
              _votesError = '$error';
              _applyLiveState();
            });
          },
        );
  }

  void _applyLiveState() {
    _loading = !_appointmentSeen || !_votesSeen;
    _error = _appointmentError ?? _votesError;
  }

  Deadline get _deadline => deadlineFor(
    _appointment.expirationDate,
    now: DateTime.now(),
    openedAt: _appointment.creationDate,
  );

  TimeSlot? get _confirmedSlot =>
      _appointment.confirmedTimeSlots.firstOrNull ??
      _appointment.availableTimeSlots.where((s) => s.isConfirmed).firstOrNull;

  bool get _canVote => !_deadline.isPassed && _confirmedSlot == null;

  VoteStatus? _statusFor(TimeSlot slot) =>
      _pending[slotKeyOf(slot)] ?? votesOf(_userId, _votes)[slotKeyOf(slot)];

  void _choose(TimeSlot slot, VoteStatus status) {
    if (!_canVote) return;
    setState(() {
      if (_statusFor(slot) == status) {
        _pending[slotKeyOf(slot)] = VoteStatus.maybe;
      } else {
        _pending[slotKeyOf(slot)] = status;
      }
    });
  }

  Future<void> _submit() async {
    if (!_canVote) {
      if (_pending.isNotEmpty) setState(_pending.clear);
      UIUtils.showSnackBar(context, 'voting_has_closed'.tr());
      return;
    }
    if (_pending.isEmpty) {
      Navigator.pop(context);
      return;
    }

    setState(() => _saving = true);

    try {
      final name = await _service.fetchUserNameById(_userId);
      if (!_canVote) {
        if (mounted) {
          setState(_pending.clear);
          UIUtils.showSnackBar(context, 'voting_has_closed'.tr());
        }
        return;
      }
      final votes = <({TimeSlot slot, String status})>[];
      for (final entry in _pending.entries) {
        final matching = _appointment.availableTimeSlots
            .where((slot) => slotKeyOf(slot) == entry.key)
            .firstOrNull;
        if (matching != null) {
          votes.add((slot: matching, status: entry.value.wireName));
        }
      }
      if (votes.isEmpty) {
        if (mounted) setState(_pending.clear);
        return;
      }
      await _service.saveVotes(
        userId: _userId,
        appointmentId: _appointment.appointmentId,
        userName: name,
        votes: votes,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      UIUtils.showSnackBar(
        context,
        (_canVote ? 'error_occurred' : 'voting_has_closed').tr(),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirm(TimeSlot slot) async {
    final startOffset = appointmentUtcOffset(slot.startAt, _appointment.zoneId);
    final endOffset = appointmentUtcOffset(slot.endAt, _appointment.zoneId);
    final creatorTime =
        '${formatAppointmentRange(startAt: slot.startAt, endAt: slot.endAt, zoneId: _appointment.zoneId, locale: context.locale.toLanguageTag())} (${_appointment.zoneId}, $startOffset'
        '${startOffset == endOffset ? '' : ' → $endOffset'})';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('confirm_this_time'.tr()),
        content: Text(
          'confirm_this_time_body'.tr(namedArgs: {'time': creatorTime}),
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
      final revision = await _service.confirmTimeSlot(
        _appointment.appointmentId,
        slot,
        expectedRevision: _appointment.revision,
      );
      if (!mounted) return;
      setState(() {
        _appointment.setConfirmedSlot(slot.slotId);
        if (_appointment.revision < revision) {
          _appointment.revision = revision;
        }
      });
    } catch (_) {
      if (!mounted) return;
      UIUtils.showSnackBar(context, 'error_occurred'.tr());
    }
  }

  Future<void> _exportCalendar() async {
    try {
      await downloadTextFile(
        contents: buildAppointmentIcs(appointment: _appointment),
        fileName: appointmentIcsFileName(_appointment),
        mimeType: 'text/calendar',
      );
    } catch (_) {
      if (mounted) UIUtils.showSnackBar(context, 'error_occurred'.tr());
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
          if (!_appointmentDeleted)
            IconButton(
              tooltip: 'all_participants'.tr(),
              icon: const Icon(Icons.group_outlined),
              onPressed: _openParticipants,
            ),
          if (!_appointmentDeleted && _confirmedSlot != null)
            IconButton(
              tooltip: 'add_to_calendar'.tr(),
              icon: const Icon(Icons.event_available_outlined),
              onPressed: _exportCalendar,
            ),
          if (widget.isAdmin && !_appointmentDeleted)
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

    if (_error != null) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'error_occurred'.tr(),
        body: _appointmentDeleted ? 'appointment_deleted'.tr() : 'retry'.tr(),
        action: _appointmentDeleted
            ? null
            : TextButton(onPressed: _load, child: Text('retry'.tr())),
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
                zoneId: _appointment.zoneId,
                tally: tally.forSlot(slot),
                myStatus: _statusFor(slot),
                isLeader:
                    tally.leader != null &&
                    tally.leader!.matches(slot) &&
                    confirmed == null,
                isTied: tally.isTied,
                enabled: _canVote,
                onChoose: (status) => _choose(slot, status),
                onShowVoters: _openParticipants,
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

  void _openParticipants() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AppointmentParticipantsPage(appointment: _appointment),
      ),
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
                  child: AppointmentTimeText(
                    startAt: confirmed!.startAt,
                    endAt: confirmed!.endAt,
                    zoneId: appointment.zoneId,
                    style: theme.textTheme.titleSmall,
                    secondaryStyle: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
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
