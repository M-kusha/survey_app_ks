import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:survey_app_ks/appointments/appointment_data.dart';
import 'package:survey_app_ks/appointments/firebase/appointment_services.dart';
import 'package:survey_app_ks/settings/font_size_provider.dart';
import 'package:survey_app_ks/utilities/tablet_size.dart';

class TimeSlotParticipantsPage extends StatefulWidget {
  final TimeSlot timeSlot;
  final Appointment appointment;

  const TimeSlotParticipantsPage({
    Key? key,
    required this.timeSlot,
    required this.appointment,
  }) : super(key: key);

  @override
  TimeSlotParticipantsPageState createState() =>
      TimeSlotParticipantsPageState();
}

class TimeSlotParticipantsPageState extends State<TimeSlotParticipantsPage> {
  late String? companyId;
  List<AppointmentParticipants>? filteredParticipants;
  List<AppointmentParticipants> allParticipants = [];
  List<TimeSlot> timeSlots = [];
  bool _isAdmin = false;
  bool _anyTimeSlotConfirmed = false;
  bool _isLoading = true;

  late AppointmentService _appointmentService;

  @override
  void initState() {
    super.initState();
    _appointmentService = AppointmentService();
    _initPage();
    _checkAnyTimeSlotConfirmed();
  }

  void _checkAnyTimeSlotConfirmed() async {
    final anyConfirmed = await _appointmentService
        .isAnyTimeSlotConfirmed(widget.appointment.appointmentId);
    setState(() {
      _anyTimeSlotConfirmed = anyConfirmed;
    });
  }

  void _initPage() async {
    final companyId = await _appointmentService.getCompanyId();
    final isAdmin = await _appointmentService.fetchAdminStatus();
    final allParticipants = await _appointmentService.fetchParticipants(
        widget.appointment.appointmentId, widget.timeSlot);

    if (!mounted) return;

    setState(() {
      this.companyId = companyId;
      _isAdmin = isAdmin;
      this.allParticipants = allParticipants;
      filteredParticipants = allParticipants;
      _isLoading = false;
    });
  }

  void filterParticipantsByStatus(String status) {
    List<AppointmentParticipants> tempFiltered;
    if (status == 'all') {
      tempFiltered = List.from(allParticipants);
    } else {
      tempFiltered = allParticipants
          .where((participant) => participant.status == status)
          .toList();
    }

    setState(() {
      filteredParticipants = tempFiltered;
    });
  }

  int getCountForStatus(String status) {
    if (status == 'all') {
      return allParticipants.length;
    } else {
      return allParticipants
          .where((participant) => participant.status == status)
          .length;
    }
  }

  final Map<String, String> filterStatusMessages = {
    'all': 'all_participants'.tr(),
    'joined': 'will_participate_participants'.tr(),
    'maybe': 'maybe_participate_participants'.tr(),
    'declined': 'will_not_participate_participants'.tr(),
  };

  @override
  Widget build(BuildContext context) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);

    return Scaffold(
      appBar: AppBar(
        title: Padding(
          padding: const EdgeInsets.only(right: 40.0, bottom: 8.0),
          child: Column(
            children: [
              Text(
                widget.appointment.title,
                style: TextStyle(fontSize: timeFontSize),
              ),
            ],
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 10),
                  Text(
                    'Loading...',
                    style: TextStyle(
                      fontSize: timeFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                buildConfirmationStatus(),
                const SizedBox(height: 16.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    buildParticipantStatus(
                        Icons.group, Colors.blue, 'all', context),
                    buildParticipantStatus(Icons.check_circle_outline_outlined,
                        Colors.green, 'joined', context),
                    buildParticipantStatus(Icons.help_outline_outlined,
                        Colors.amber, 'maybe', context),
                    buildParticipantStatus(
                        Icons.cancel_outlined, Colors.red, 'declined', context),
                  ],
                ),
                buildParticipantsList(),
              ],
            ),
    );
  }

  Widget buildConfirmationStatus() {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);
    final timeSlot = widget.timeSlot;
    final dayOfWeek = DateFormat('EEEE').format(timeSlot.start);
    final dayOfMonth = DateFormat('d').format(timeSlot.start);
    final monthOfYear = DateFormat('MMMM').format(timeSlot.start);
    final timeFormat = DateFormat.jm();
    final startTimeString = timeFormat.format(timeSlot.start);
    final endTimeString = timeFormat.format(timeSlot.end);
    List<TimeSlot> confirmedTimeSlots = Provider.of<List<TimeSlot>>(context);

    bool isTimeSlotConfirmed = confirmedTimeSlots.any((ts) =>
        ts.start.isAtSameMomentAs(widget.timeSlot.start) &&
        ts.end.isAtSameMomentAs(widget.timeSlot.end));
    final disableButton = _anyTimeSlotConfirmed && !isTimeSlotConfirmed;

    return Column(children: [
      const SizedBox(height: 16.0),
      Text(
        '$dayOfWeek $dayOfMonth $monthOfYear',
        style: TextStyle(fontSize: timeFontSize, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 8.0),
      Text('$startTimeString - $endTimeString',
          style: TextStyle(fontSize: timeFontSize - 2)),
      const SizedBox(height: 16.0),
      if (_isAdmin && !disableButton)
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0)),
            backgroundColor: isTimeSlotConfirmed ? Colors.grey : Colors.blue,
          ),
          onPressed: isTimeSlotConfirmed
              ? null
              : () async {
                  await _appointmentService.confirmTimeSlot(
                      widget.appointment.appointmentId, widget.timeSlot);
                },
          child: SizedBox(
            width: isTimeSlotConfirmed
                ? timeFontSize * 20
                : timeFontSize * 9, // Adjust width as needed
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                    isTimeSlotConfirmed
                        ? 'this_time_slot_is_confirmed'.tr()
                        : 'confirm'.tr(),
                    style: TextStyle(fontSize: timeFontSize)),
                const SizedBox(width: 8.0),
                Icon(isTimeSlotConfirmed
                    ? Icons.check_circle_outline_outlined
                    : Icons.check_circle_outline),
              ],
            ),
          ),
        ),
      if (_isAdmin && disableButton)
        Container(
          width: timeFontSize * 20,
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.grey[200]
                : Colors.grey[900],
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'another_time_slot_is_confirmed'.tr(),
                  style: TextStyle(fontSize: timeFontSize),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
    ]);
  }

  Widget buildParticipantsList() {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);

    if (filteredParticipants?.isEmpty ?? true) {
      return Expanded(
        child: Center(
          child: Text(
            "no_participants".tr(),
            style: TextStyle(fontSize: timeFontSize),
          ),
        ),
      );
    } else {
      return Expanded(
        child: ListView.builder(
          itemCount: filteredParticipants?.length,
          itemBuilder: (context, index) {
            final participant = filteredParticipants?[index];
            return Card(
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: CircleAvatar(
                      child: Text(
                        participant!.userName[0],
                        style: TextStyle(fontSize: timeFontSize),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          participant.userName,
                          style: TextStyle(
                              fontSize: timeFontSize,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Icon(
                      participant.status == 'joined'
                          ? Icons.check_circle_outline_outlined
                          : participant.status == 'maybe'
                              ? Icons.help_outline_outlined
                              : Icons.cancel_outlined,
                      color: participant.status == 'joined'
                          ? Colors.green
                          : participant.status == 'maybe'
                              ? Colors.amber
                              : Colors.red,
                      size: timeFontSize * 1.3,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }
  }

  Widget buildParticipantStatus(
      IconData icon, Color color, String status, BuildContext context) {
    int count = getCountForStatus(status);
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);

    return Expanded(
      child: InkWell(
        onTap: () => filterParticipantsByStatus(status),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(icon, color: color, size: timeFontSize * 1.3),
              const SizedBox(height: 8.0),
              Text("$count",
                  style: TextStyle(
                      fontSize: timeFontSize, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
