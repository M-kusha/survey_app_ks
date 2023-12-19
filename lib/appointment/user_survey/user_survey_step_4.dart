import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:ntfy_dart/ntfy_dart.dart';
import 'package:provider/provider.dart';
import 'package:survey_app_ks/appointment/main_survey/survey_main.dart';
import 'package:survey_app_ks/appointment/survey_class.dart';
import 'package:survey_app_ks/settings/font_size_provider.dart';
import 'package:survey_app_ks/utilities/ntfy_interface.dart';
import 'package:survey_app_ks/utilities/tablet_size.dart';

class TimeSlotParticipantsPage extends StatefulWidget {
  final TimeSlot timeSlot;
  final Survey survey;

  const TimeSlotParticipantsPage(
      {Key? key, required this.timeSlot, required this.survey})
      : super(key: key);

  @override
  TimeSlotParticipantsPageState createState() =>
      TimeSlotParticipantsPageState();
}

class TimeSlotParticipantsPageState extends State<TimeSlotParticipantsPage> {
  final _ntfy = NtfyInterface();
  String _currentFilterStatus = 'all';

  Future<void> _sendNotification() async {
    final timeSlot = widget.timeSlot;
    final dayOfWeek = DateFormat('EEEE').format(timeSlot.start);
    final dayOfMonth = DateFormat('d').format(timeSlot.start);
    final monthOfYear = DateFormat('MMMM').format(timeSlot.start);
    final timeFormat = DateFormat.jm();
    final startTimeString = timeFormat.format(timeSlot.start);
    final endTimeString = timeFormat.format(timeSlot.end);
    final message = PublishableMessage(
      topic: 'Intranet',
      title:
          '${widget.survey.title} ${'survey_time_confirmed_notification'.tr()}',
      message:
          '$dayOfWeek $dayOfMonth $monthOfYear, $startTimeString - $endTimeString',
    );

    await _ntfy.publish(message);
  }

  List<Participant> filteredParticipants = [];
  String? _password = '';

  @override
  void initState() {
    super.initState();
    filterParticipantsByStatus('joined');
  }

  void filterParticipantsByStatus(String status) {
    setState(() {
      filteredParticipants = widget.survey.participants
          .where((participant) =>
              (status == 'all' || participant.status == status) &&
              participant.timeSlot.start == widget.timeSlot.start &&
              participant.timeSlot.end == widget.timeSlot.end)
          .toList();
      _currentFilterStatus = status;
    });
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
    final count = widget.survey.participants
        .where((participant) =>
            participant.timeSlot.start == widget.timeSlot.start &&
            participant.timeSlot.end == widget.timeSlot.end)
        .length;
    return Scaffold(
      appBar: AppBar(
        title: Padding(
          padding: const EdgeInsets.only(right: 40.0, bottom: 8.0),
          child: Column(
            children: [
              Text(widget.survey.title,
                  style: TextStyle(
                    fontSize: timeFontSize,
                  )),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${count.toString()} ${'participants'.tr()}',
                    style: TextStyle(
                      fontSize: timeFontSize,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          buildConfirmationStatus(),
          const SizedBox(height: 16.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              buildParticipantStatus(Icons.group, Colors.blue, 'all', context),
              buildParticipantStatus(Icons.check_circle_outline_outlined,
                  Colors.green, 'joined', context),
              buildParticipantStatus(
                  Icons.help_outline_outlined, Colors.amber, 'maybe', context),
              buildParticipantStatus(
                  Icons.cancel_outlined, Colors.red, 'declined', context),
            ],
          ),
          if (_currentFilterStatus
              .isNotEmpty) // only show if a filter is applied
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                filterStatusMessages[_currentFilterStatus]!,
                style: TextStyle(
                  fontSize: timeFontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
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

    bool isAnyTimeSlotConfirmed = false;
    for (final timeSlot in widget.survey.availableTimeSlots) {
      if (widget.survey.confirmedTimeSlots.contains(timeSlot)) {
        isAnyTimeSlotConfirmed = true;
        break;
      }
    }

    final isConfirmed =
        widget.survey.confirmedTimeSlots.contains(widget.timeSlot);

    return Column(
      children: [
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
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            backgroundColor: isConfirmed || isAnyTimeSlotConfirmed
                ? Colors.grey.shade400
                : Colors.blue,
          ),
          onPressed: isConfirmed || isAnyTimeSlotConfirmed
              ? null
              : () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        shape: const RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(10.0))),
                        title: Row(
                          children: [
                            Text('enter_edit_password'.tr(),
                                style: TextStyle(fontSize: timeFontSize)),
                            SizedBox(
                              width: timeFontSize * 2.0,
                            ),
                            Icon(Icons.lock, size: timeFontSize),
                          ],
                        ),
                        content: TextField(
                          decoration: InputDecoration(
                            hintText: 'enter_edit_password_hint'.tr(),
                            hintStyle: TextStyle(fontSize: timeFontSize),
                          ),
                          onChanged: (value) {
                            _password = value;
                          },
                          obscureText: true,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: Text('cancel'.tr(),
                                style: TextStyle(fontSize: timeFontSize)),
                          ),
                          TextButton(
                            onPressed: () {
                              if (_password == widget.survey.password) {
                                if (!widget.survey.confirmedTimeSlots
                                    .contains(widget.timeSlot)) {
                                  widget.survey.confirmedTimeSlots
                                      .add(widget.timeSlot);
                                }
                                _sendNotification();
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const SurveyPageUI(),
                                  ),
                                  (route) => false,
                                );
                              } else {
                                Navigator.of(context).pop();
                              }
                            },
                            child: Text(
                              'confirm'.tr(),
                              style: TextStyle(fontSize: timeFontSize),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
          child: SizedBox(
            width: timeFontSize * 9,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isConfirmed ? 'confirmed'.tr() : 'confirm'.tr(),
                  style: TextStyle(fontSize: timeFontSize),
                ),
                const SizedBox(width: 8.0),
                Icon(
                  isConfirmed
                      ? Icons.check_circle_outline_outlined
                      : Icons.check_circle_outline,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget buildParticipantsList() {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);

    if (filteredParticipants.isEmpty) {
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
          itemCount: filteredParticipants.length,
          itemBuilder: (context, index) {
            final participant = filteredParticipants[index];
            return Card(
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: CircleAvatar(
                      child: Text(
                        participant.userName[0],
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
                            fontWeight: FontWeight.bold,
                          ),
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
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);
    final count = widget.survey.participants
        .where((participant) =>
            ((status == 'all') || (participant.status == status)) &&
            participant.timeSlot.start == widget.timeSlot.start &&
            participant.timeSlot.end == widget.timeSlot.end)
        .length;

    return Expanded(
      child: InkWell(
        onTap: () {
          filterParticipantsByStatus(status);
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(
                icon,
                color: color,
                size: timeFontSize * 1.3,
              ),
              const SizedBox(height: 8.0),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: timeFontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
