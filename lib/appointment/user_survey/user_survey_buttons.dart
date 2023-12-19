import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:survey_app_ks/appointment/survey_class.dart';
import 'package:survey_app_ks/appointment/survey_edit/survey_edit.dart';
import 'package:survey_app_ks/appointment/user_survey/user_survey_step_2.dart';
import 'package:survey_app_ks/appointment/user_survey/user_survey_step_3.dart';
import 'package:survey_app_ks/settings/font_size_provider.dart';
import 'package:survey_app_ks/utilities/tablet_size.dart';

class SurveyUserSelectCategories extends StatefulWidget {
  final Survey survey;
  final TimeSlot timeSlot;
  final String userName;
  const SurveyUserSelectCategories(
      {super.key,
      required this.survey,
      required this.userName,
      required this.timeSlot});

  @override
  SurveyUserSelectCategoriesState createState() =>
      SurveyUserSelectCategoriesState();
}

class SurveyUserSelectCategoriesState
    extends State<SurveyUserSelectCategories> {
  bool participateSelected = true;
  bool overviewSelected = false;
  String? _password = '';
  Survey? numberOfParticipants;

  @override
  void initState() {
    super.initState();
    overviewSelected = widget.survey.disableIfYouParticipated;
    if (overviewSelected) {
      participateSelected = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(widget.survey.title, style: TextStyle(fontSize: timeFontSize)),
            const SizedBox(width: 8),
          ],
        ),
        centerTitle: true,
        actions: [buildEditSection()],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  left: 25.0,
                  right: 25.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () {
                        if (!widget.survey.disableIfYouParticipated) {
                          setState(() {
                            participateSelected = true;
                            overviewSelected = false;
                          });
                        }
                      },
                      style: ButtonStyle(
                        overlayColor: MaterialStateColor.resolveWith(
                          (states) => widget.survey.disableIfYouParticipated
                              ? Colors
                                  .transparent // set to transparent to disable ripple effect
                              : Colors.grey.withOpacity(
                                  0.1), // set overlay color for normal state
                        ),
                      ),
                      child: Text(
                        'participate'.tr(),
                        style: TextStyle(
                          color:
                              participateSelected ? Colors.green : Colors.grey,
                          fontSize: timeFontSize,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          participateSelected = false;
                          overviewSelected = true;
                        });
                      },
                      style: ButtonStyle(
                        overlayColor: MaterialStateColor.resolveWith(
                          (states) => widget.survey.disableIfYouParticipated
                              ? Colors
                                  .transparent // set to transparent to disable ripple effect
                              : Colors.grey.withOpacity(
                                  0.1), // set overlay color for normal state
                        ),
                      ),
                      child: Text(
                        'overview'.tr(),
                        style: TextStyle(
                          color: overviewSelected ? Colors.green : Colors.grey,
                          fontSize: timeFontSize,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    flex: 2,
                    child: Container(
                      height: 2,
                      color: participateSelected ? Colors.green : Colors.grey,
                    ),
                  ),
                  Expanded(
                    flex: 0,
                    child: Container(
                      height: 2,
                      color: Colors.black,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Container(
                      height: 2,
                      color: overviewSelected ? Colors.green : Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
          if (participateSelected)
            Positioned(
              top: 70.0,
              left: 0.0,
              right: 0.0,
              bottom: 100.0,
              child: SurveyParticipate(
                survey: widget.survey,
                userName: widget.userName,
              ),
            ),
          if (overviewSelected)
            Positioned(
              top: 70.0,
              left: 0.0,
              right: 0.0,
              bottom: 100.0,
              child: ParticipantOverviewPage(
                survey: widget.survey,
              ),
            ),
          if (participateSelected)
            Positioned(
              bottom: 0.0,
              left: 0.0,
              right: 0.0,
              child: buildParticipateButton(context),
            ),
        ],
      ),
      // bottomNavigationBar: const BottomNavigation(
      //   initialIndex: 4,
      // ),
    );
  }

  Widget buildParticipateButton(BuildContext context) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);
    final screenWidth = MediaQuery.of(context).size.width;
    return SizedBox(
      width: double.infinity,
      child: Column(
        children: [
          SizedBox(
            width: screenWidth * 0.4,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: Size.fromHeight(timeFontSize * 1.0),
                padding: EdgeInsets.symmetric(vertical: timeFontSize * 0.5),
              ),
              onPressed: () async {
                setState(() {
                  overviewSelected = true;
                  participateSelected = false;
                  widget.survey.disableIfYouParticipated = true;
                });
              },
              child:
                  Text('next'.tr(), style: TextStyle(fontSize: timeFontSize)),
            ),
          ),
          const SizedBox(height: 16.0),
        ],
      ),
    );
  }

  Widget buildEditSection() {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);
    return IconButton(
      icon: const Icon(Icons.edit),
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(10.0))),
            title: Row(
              children: [
                Text('enter_edit_password'.tr(),
                    style: TextStyle(fontSize: timeFontSize)),
                SizedBox(
                  width: timeFontSize * 2.0,
                ),
                Icon(
                  Icons.lock,
                  size: timeFontSize,
                ),
              ],
            ),
            content: TextFormField(
              onChanged: (value) {
                _password = value;
              },
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'enter_edit_password_hint'.tr(),
                hintStyle: TextStyle(fontSize: timeFontSize),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () {
                    if (_password == widget.survey.password) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SurveyEditPage(
                            survey: widget.survey,
                            userName: '',
                            timeSlot: widget.timeSlot,
                          ),
                        ),
                      ).then((_) => Navigator.pop(context));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('invalid_password'.tr(),
                              textAlign: TextAlign.center),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  child: Text(
                    'confirm'.tr(),
                    style: TextStyle(fontSize: timeFontSize),
                  )),

              // close the dialog
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('cancel'.tr(),
                    style: TextStyle(fontSize: timeFontSize)),
              ),
            ],
          ),
        );
      },
    );
  }
}
