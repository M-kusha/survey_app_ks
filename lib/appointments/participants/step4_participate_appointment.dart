import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/appointments/appointment_data.dart';
import 'package:echomeet/appointments/firebase/appointment_services.dart';
import 'package:echomeet/appointments/participants/user_profile_short.dart';
import 'package:echomeet/settings/font_size_provider.dart';
import 'package:echomeet/utilities/reusable_widgets.dart';
import 'package:echomeet/utilities/tablet_size.dart';
import 'package:echomeet/utilities/text_style.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TimeSlotParticipantsPage extends StatefulWidget {
  final TimeSlot timeSlot;
  final Appointment appointment;
  final bool isAdmin;

  const TimeSlotParticipantsPage({
    Key? key,
    required this.timeSlot,
    required this.appointment,
    required this.isAdmin,
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
  String? imageUrl;

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
    final isAdmin = widget.isAdmin;
    List<AppointmentParticipants> allParticipantsWithImages = [];

    final allParticipants = await _appointmentService.fetchParticipants(
        widget.appointment.appointmentId, widget.timeSlot);

    for (var participant in allParticipants) {
      String imageUrl =
          await _appointmentService.fetchProfileImage(participant.userId);

      String userName =
          await _appointmentService.fetchUserNameById(participant.userId);
      participant.profileImageUrl = imageUrl;
      participant.userName = userName;
      allParticipantsWithImages.add(participant);
    }

    if (!mounted) return;

    setState(() {
      this.companyId = companyId;
      _isAdmin = isAdmin;
      this.allParticipants = allParticipantsWithImages;
      filteredParticipants = allParticipantsWithImages;
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
        title: Text(
          widget.appointment.title,
          style: TextStyle(
            fontSize: timeFontSize * 1.5,
          ),
        ),
        backgroundColor: getAppbarColor(context),
        centerTitle: true,
      ),
      body: _isLoading
          ? const CustomLoadingWidget(
              loadingText: 'loading',
            )
          : Column(
              children: [
                Card(
                  elevation: 3,
                  shadowColor: getButtonColor(context),
                  child: Column(
                    children: [
                      buildConfirmationStatus(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          buildParticipantStatus(
                              Icons.group, Colors.blue, 'all', context),
                          buildParticipantStatus(
                              Icons.check_circle_outline_outlined,
                              Colors.green,
                              'joined',
                              context),
                          buildParticipantStatus(Icons.help_outline_outlined,
                              Colors.amber, 'maybe', context),
                          buildParticipantStatus(Icons.cancel_outlined,
                              Colors.red, 'declined', context),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16.0),
                buildParticipantsList(),
              ],
            ),
    );
  }

  Widget buildConfirmationStatus() {
    final textColor = getListTileColor(context);
    final buttonColor = getButtonColor(context);
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);
    final timeSlot = widget.timeSlot;
    final timeFormat = DateFormat.jm();
    final startTimeString = timeFormat.format(timeSlot.start);
    final endTimeString = timeFormat.format(timeSlot.end);
    String formattedDate = DateFormat.yMMMd().format(timeSlot.start);
    List<TimeSlot> confirmedTimeSlots = Provider.of<List<TimeSlot>>(context);

    bool isTimeSlotConfirmed = confirmedTimeSlots.any((ts) =>
        ts.start.isAtSameMomentAs(widget.timeSlot.start) &&
        ts.end.isAtSameMomentAs(widget.timeSlot.end));

    return Column(children: [
      const SizedBox(height: 16.0),
      SizedBox(
        width: 350,
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(
              color: buttonColor,
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Stack(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today,
                            size: timeFontSize * 1.1, color: buttonColor),
                        const SizedBox(width: 5),
                        Text(formattedDate,
                            style: TextStyle(
                                fontSize: timeFontSize * 1.1,
                                fontWeight: FontWeight.bold,
                                color: buttonColor)),
                      ],
                    ),
                    const SizedBox(height: 8.0),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        children: [
                          WidgetSpan(
                              child: Icon(Icons.access_time,
                                  size: timeFontSize * 1.1,
                                  color: buttonColor)),
                          TextSpan(
                              text: " $startTimeString - $endTimeString",
                              style: TextStyle(
                                  fontSize: timeFontSize * 0.9,
                                  fontWeight: FontWeight.bold,
                                  color: buttonColor)),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_isAdmin)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: !_anyTimeSlotConfirmed || isTimeSlotConfirmed
                            ? () {
                                if (!isTimeSlotConfirmed) {
                                  confirmTimeSlotDialog();
                                }
                              }
                            : null,
                        child: Icon(
                          isTimeSlotConfirmed ? Icons.alarm_on : Icons.alarm,
                          color: isTimeSlotConfirmed
                              ? buttonColor
                              : _anyTimeSlotConfirmed
                                  ? Colors.red
                                  : textColor,
                          size: timeFontSize * 1.8,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 16.0),
    ]);
  }

  Future<dynamic> confirmTimeSlotDialog() {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "confirm_time_slot".tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.alarm, color: Colors.blueGrey),
            ],
          ),
          content: Text(
            "confirm_time_slot_tip".tr(),
          ),
          actions: <Widget>[
            TextButton(
              child: Text("cancel".tr()),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text("confirm".tr()),
              onPressed: () async {
                Navigator.of(context).pop();
                await _appointmentService.confirmTimeSlot(
                    widget.appointment.appointmentId, widget.timeSlot);
              },
            ),
          ],
        );
      },
    );
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
            final participant = filteredParticipants![index];
            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              elevation: 3,
              shadowColor: getButtonColor(context),
              margin:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
              child: ListTile(
                leading: GestureDetector(
                  onTap: () {
                    userProfile(context, participant);
                  },
                  child: CircleAvatar(
                    radius: timeFontSize * 1.3,
                    backgroundImage: participant.profileImageUrl.isNotEmpty
                        ? NetworkImage(participant.profileImageUrl)
                        : null,
                    backgroundColor: Colors.blueGrey,
                    child: participant.profileImageUrl.isEmpty
                        ? Text(
                            participant.userName.isNotEmpty
                                ? participant.userName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                                fontSize: timeFontSize * 1.1,
                                color: Colors.white),
                          )
                        : null,
                  ),
                ),
                title: Padding(
                  padding: const EdgeInsets.only(
                    left: 20.0,
                  ),
                  child: Text(
                    participant.userName,
                    style: TextStyle(
                        fontSize: timeFontSize * 1.2,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                trailing: Icon(
                  _getStatusIcon(participant.status),
                  color: _getStatusColor(participant.status),
                  size: timeFontSize * 1.5,
                ),
              ),
            );
          },
        ),
      );
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'joined':
        return Icons.check_circle_outline;
      case 'maybe':
        return Icons.help_outline;
      case 'declined':
        return Icons.cancel_outlined;
      default:
        return Icons.error_outline;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'joined':
        return Colors.green;
      case 'maybe':
        return Colors.amber;
      case 'declined':
        return Colors.red;
      default:
        return Colors.grey;
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
