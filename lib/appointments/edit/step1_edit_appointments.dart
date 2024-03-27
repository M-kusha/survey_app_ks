import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:survey_app_ks/appointments/appointment_data.dart';
import 'package:survey_app_ks/settings/font_size_provider.dart';
import 'package:survey_app_ks/utilities/tablet_size.dart';
import 'package:survey_app_ks/utilities/text_style.dart';

class AppointmentEditPageStep1 extends StatefulWidget {
  final Appointment appointment;
  final Function(int) onPageChange;

  const AppointmentEditPageStep1({
    Key? key,
    required this.appointment,
    required this.onPageChange,
  }) : super(key: key);

  @override
  AppointmentEditPageStep1State createState() =>
      AppointmentEditPageStep1State();
}

class AppointmentEditPageStep1State extends State<AppointmentEditPageStep1> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.appointment.title);
    _descriptionController =
        TextEditingController(text: widget.appointment.description);
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);

    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(timeFontSize * 1.5),
          child: Card(
            elevation: 5,
            shadowColor: getButtonColor(context),
            child: Form(
              key: _formKey,
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
                      onChanged: (value) {
                        setState(() {
                          widget.appointment.title = value;
                        });
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
                      maxLength: 1000,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: 'create_appointment_description_hint'.tr(),
                        hintStyle: TextStyle(fontSize: timeFontSize * 1.2),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'create_appointment_description_error'.tr();
                        }
                        return null;
                      },
                      onChanged: (value) {
                        setState(() {
                          widget.appointment.description = value;
                        });
                      },
                    ),
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.4,
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
  }
}
