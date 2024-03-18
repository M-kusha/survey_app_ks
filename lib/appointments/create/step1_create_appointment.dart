import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:survey_app_ks/appointments/appointment_data.dart';
import 'package:survey_app_ks/settings/font_size_provider.dart';
import 'package:survey_app_ks/utilities/reusable_widgets.dart';
import 'package:survey_app_ks/utilities/tablet_size.dart';

class Step1CreateAppointment extends StatefulWidget {
  const Step1CreateAppointment({Key? key}) : super(key: key);

  @override
  Step1CreateAppointmentState createState() => Step1CreateAppointmentState();
}

class Step1CreateAppointmentState extends State<Step1CreateAppointment> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final Appointment _newAppointment = Appointment(
    title: '',
    description: '',
    participants: [],
    availableDates: [],
    availableTimeSlots: [],
    appointmentId: '',
    confirmedTimeSlots: [],
    expirationDate: DateTime.now(),
    participationCount: 0,
  );
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  int? maxLines;

  @override
  void initState() {
    super.initState();
    _descriptionController.addListener(() {
      setState(() {
        maxLines = null;
      });
    });
  }

  void _onNextPressed() async {
    if (_titleController.text.isEmpty || _descriptionController.text.isEmpty) {
      UIUtils.showSnackBar(
        context,
        'create_appointment_error_snackbar'.tr(),
      );
    } else if (_formKey.currentState!.validate()) {
      Navigator.pushNamed(
        context,
        '/create_appointment_step_2',
        arguments: _newAppointment,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'create_appointment'.tr(),
          style: TextStyle(fontSize: timeFontSize + 3),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(timeFontSize * 1.5),
                child: Card(
                  child: Form(
                    key: _formKey,
                    child: GestureDetector(
                      onTap: () {
                        FocusScope.of(context).requestFocus(FocusNode());
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 20.0),
                            Text(
                              'create_appointment_title'.tr(),
                              style: TextStyle(
                                fontSize: timeFontSize,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextFormField(
                              style: TextStyle(fontSize: timeFontSize),
                              controller: _titleController,
                              decoration: InputDecoration(
                                hintText: 'create_appointment_hint'.tr(),
                                hintStyle: TextStyle(fontSize: timeFontSize),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'create_appointment_title_error'.tr();
                                }
                                return null;
                              },
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                              onChanged: (value) {
                                _newAppointment.title = value;
                              },
                            ),
                            const SizedBox(height: 20.0),
                            Text(
                              'create_appointment_description'.tr(),
                              style: TextStyle(
                                fontSize: timeFontSize,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextFormField(
                              style: TextStyle(fontSize: timeFontSize),
                              strutStyle: const StrutStyle(
                                forceStrutHeight: true,
                                height: 1.5,
                              ),
                              controller: _descriptionController,
                              maxLength: 256,
                              maxLines: maxLines,
                              decoration: InputDecoration(
                                hintText:
                                    'create_appointment_description_hint'.tr(),
                                hintStyle:
                                    TextStyle(fontSize: timeFontSize * 1.2),
                                counterText:
                                    '${_descriptionController.text.length}/256',
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'create_appointment_description_error'
                                      .tr();
                                }
                                return null;
                              },
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                              onChanged: (value) {
                                setState(() {
                                  _newAppointment.description = value;
                                });
                              },
                              onTap: () {
                                setState(() {
                                  maxLines = null;
                                });
                              },
                              onEditingComplete: () {
                                setState(() {
                                  maxLines = 1;
                                });
                              },
                            ),
                            SizedBox(
                              height: constraints.maxHeight * 0.4,
                              child: Text(
                                '',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: buildBottomElevatedButton(
        context: context,
        onPressed: _onNextPressed,
        buttonText: 'next',
      ),
    );
  }
}
