import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/appointments/appointment_data.dart';
import 'package:echomeet/appointments/firebase/appointment_provider.dart';
import 'package:echomeet/appointments/main_screen/appointment_list.dart';
import 'package:echomeet/appointments/main_screen/create_appointment_button.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/membership/company_gate.dart';
import 'package:echomeet/core/membership/membership.dart';
import 'package:echomeet/core/layout/page_body.dart';
import 'package:echomeet/core/widgets/feature_kit.dart';
import 'package:echomeet/core/widgets/sign_out_button.dart';
import 'package:echomeet/survey_pages/utilities/survey_data_provider.dart';
import 'package:echomeet/utilities/firebase_services.dart';
import 'package:echomeet/utilities/reusable_widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

enum AppointmentSort { newest, oldest, closingSoon, mostVotes }

class AppointmentPageUI extends StatefulWidget {
  const AppointmentPageUI({super.key});

  @override
  State<AppointmentPageUI> createState() => AppointmentPageUIState();
}

class AppointmentPageUIState extends State<AppointmentPageUI> {
  final _searchController = TextEditingController();

  AppointmentSort _sort = AppointmentSort.newest;
  bool _isAdmin = false;
  bool _isLoading = true;
  String? _error;
  Membership? _membership;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() => _load(silent: true);

  Future<void> _load({bool silent = false}) async {
    final appointments = Provider.of<AppointmentDataProvider>(
      context,
      listen: false,
    );
    final users = Provider.of<UserDataProvider>(context, listen: false);
    final services = Provider.of<FirebaseServices>(context, listen: false);
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    setState(() {
      _isLoading = !silent;
      _error = null;
    });

    try {
      await users.loadCurrentUser();
      if (!mounted) return;

      final membership = await MembershipService().resolve();
      if (!mounted) return;

      if (!membership.isActive) {
        setState(() {
          _membership = membership;
          _isLoading = false;
        });
        return;
      }

      _membership = membership;
      final companyId = membership.companyId;

      await appointments.loadAppointments(companyId);
      await appointments.preloadUserParticipationStatus(userId);
      await appointments.preloadAppointmentsTimeSlotConfirmation();

      final isAdmin = await services.fetchAdminStatus();

      if (!mounted) return;

      setState(() {
        _isAdmin = isAdmin;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _isLoading = false;
      });
    }
  }

  ({
    List<Appointment> waiting,
    List<Appointment> done,
    List<Appointment> closed,
  })
  _group(List<Appointment> appointments, AppointmentDataProvider provider) {
    final now = DateTime.now();

    bool voted(Appointment a) =>
        provider.userParticipationStatus[a.appointmentId] ?? false;

    bool settled(Appointment a) =>
        a.availableTimeSlots.any((slot) => slot.isConfirmed);

    bool live(Appointment a) => a.expirationDate.isAfter(now) && !settled(a);

    return (
      waiting: appointments.where((a) => live(a) && !voted(a)).toList(),
      done: appointments.where((a) => live(a) && voted(a)).toList(),
      closed: appointments.where((a) => !live(a)).toList(),
    );
  }

  List<Appointment> _visible(List<Appointment> appointments) {
    final needle = _searchController.text.trim().toLowerCase();

    final result = appointments
        .where(
          (appointment) =>
              needle.isEmpty ||
              appointment.title.toLowerCase().contains(needle),
        )
        .toList();

    result.sort(
      (a, b) => switch (_sort) {
        AppointmentSort.newest => b.creationDate.compareTo(a.creationDate),
        AppointmentSort.oldest => a.creationDate.compareTo(b.creationDate),
        AppointmentSort.closingSoon => a.expirationDate.compareTo(
          b.expirationDate,
        ),
        AppointmentSort.mostVotes => b.participationCount.compareTo(
          a.participationCount,
        ),
      },
    );

    return result;
  }

  String _waitingLabel(int count) => count == 0
      ? 'all_caught_up'.tr()
      : 'needs_you_count'.tr(namedArgs: {'count': '$count'});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppointmentDataProvider>(context);
    final appointments = _visible(provider.appointments);

    if (!_isLoading && _membership?.isActive != true) {
      return CompanyGate(
        membership: _membership,
        onChanged: _load,
        child: const SizedBox.shrink(),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: PageBody(
          maxWidth: 720,

          scrollable: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: Spacing.xl),
              ScreenHeader(
                title: 'appointments'.tr(),

                subtitle: _isLoading
                    ? null
                    : _waitingLabel(
                        _group(provider.appointments, provider).waiting.length,
                      ),
                actions: const [SignOutOnCompact()],
              ),
              const SizedBox(height: Spacing.lg),
              Row(
                children: [
                  Expanded(
                    child: SearchPill(
                      controller: _searchController,
                      hint: 'search_hint'.tr(),
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  _buildSortMenu(),
                ],
              ),
              Expanded(child: _buildBody(provider, appointments)),
            ],
          ),
        ),
      ),
      floatingActionButton: _isAdmin
          ? buildCreateAppointmentButton(context)
          : null,
    );
  }

  Widget _buildSortMenu() {
    return PopupMenuButton<AppointmentSort>(
      tooltip: 'sort'.tr(),
      initialValue: _sort,
      onSelected: (value) => setState(() => _sort = value),
      itemBuilder: (context) => [
        for (final (sort, labelKey, icon) in const [
          (AppointmentSort.newest, 'newest', Icons.arrow_downward_rounded),
          (AppointmentSort.oldest, 'oldest', Icons.arrow_upward_rounded),
          (
            AppointmentSort.closingSoon,
            'exp_date_asc',
            Icons.event_busy_rounded,
          ),
          (AppointmentSort.mostVotes, 'participants', Icons.groups_rounded),
        ])
          PopupMenuItem(
            value: sort,
            child: Row(
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: Spacing.md),
                Text(labelKey.tr()),
              ],
            ),
          ),
      ],
      child: CircleAction(
        icon: Icons.sort_rounded,
        tooltip: 'sort'.tr(),
        active: _sort != AppointmentSort.newest,
        onTap: null,
      ),
    );
  }

  Widget _buildBody(
    AppointmentDataProvider provider,
    List<Appointment> appointments,
  ) {
    if (_isLoading) {
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

    if (appointments.isEmpty) {
      return _searchController.text.isEmpty
          ? EmptyState(
              icon: Icons.event_note_outlined,
              title: 'no_appointments_added_yet'.tr(),
              body: 'no_appointments_body'.tr(),
            )
          : EmptyState(
              icon: Icons.search_off_rounded,
              title: 'search_survey_or_test_not_found'.tr(),
              action: TextButton(
                onPressed: _searchController.clear,
                child: Text('clear_search'.tr()),
              ),
            );
    }

    final (:waiting, :done, :closed) = _group(appointments, provider);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 96),

        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          for (final (labelKey, group) in [
            ('section_needs_you', waiting),
            ('section_done', done),
            ('section_closed', closed),
          ])
            if (group.isNotEmpty) ...[
              SectionLabel(label: labelKey.tr(), count: group.length),
              for (final appointment in group)
                Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.md),
                  child: AppointmentListItem(
                    appointment: appointment,
                    hasUserParticipated:
                        provider.userParticipationStatus[appointment
                            .appointmentId] ??
                        false,
                    isAdmin: _isAdmin,
                    isAnyTimeSLotConfirmed:
                        provider.isAnyTimeSlotConfirmed[appointment
                            .appointmentId] ??
                        false,
                    onChanged: _refresh,
                  ),
                ),
            ],
        ],
      ),
    );
  }
}
