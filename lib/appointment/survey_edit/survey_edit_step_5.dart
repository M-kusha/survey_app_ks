import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:survey_app_ks/appointment/survey_class.dart';
import 'package:survey_app_ks/settings/font_size_provider.dart';
import 'package:survey_app_ks/utilities/tablet_size.dart';

class SurveyEditPageStep5 extends StatefulWidget {
  final Survey survey;
  final TimeSlot timeSlot;
  final Function(int) onPageChange;

  const SurveyEditPageStep5({
    Key? key,
    required this.survey,
    required this.onPageChange,
    required this.timeSlot,
  }) : super(key: key);

  @override
  SurveyEditPageStep5State createState() => SurveyEditPageStep5State();
}

class SurveyEditPageStep5State extends State<SurveyEditPageStep5> {
  bool isChecked = false;
  @override
  void initState() {
    super.initState();
    isChecked = widget.survey.confirmedTimeSlots.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('editing_confirmation_status'.tr(),
                style: TextStyle(
                  fontSize: timeFontSize,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.start),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('editing_confirmation_status_tip'.tr(),
                style: TextStyle(
                    fontSize: timeFontSize - 2, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 22),
          CheckboxListTile(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'confirmation_status'.tr(),
                  style: TextStyle(
                    fontSize: timeFontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            value: isChecked,
            onChanged: (value) {
              if (value == false &&
                  widget.survey.confirmedTimeSlots.isNotEmpty) {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text(
                          'editing_confirmation_status_dialog_title'.tr(),
                          style: TextStyle(
                              fontSize: timeFontSize,
                              fontWeight: FontWeight.bold)),
                      content: Text(
                        'editing_confirmation_status_dialog_content'.tr(),
                        style: TextStyle(
                          fontSize: timeFontSize - 2,
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: Text('cancel'.tr(),
                              style: TextStyle(
                                fontSize: timeFontSize - 2,
                              )),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              widget.survey.confirmedTimeSlots.clear();
                            });

                            Navigator.of(context).pop();
                          },
                          child: Text('confirm'.tr(),
                              style: TextStyle(
                                fontSize: timeFontSize - 2,
                              )),
                        ),
                      ],
                    );
                  },
                );
              } else {
                setState(() {
                  isChecked = value!;
                });
              }
            },
            enabled: isChecked,
            checkColor: isChecked ? Colors.white : Colors.blue,
            activeColor:
                isChecked ? Theme.of(context).primaryColor : Colors.blue,
          ),
        ],
      ),
    );
  }
}
