import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/appointments/appointment_data.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/time/device_time_zone.dart';
import 'package:echomeet/core/widgets/app_text_field.dart';
import 'package:echomeet/core/widgets/wizard_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class Step1CreateAppointment extends StatefulWidget {
  const Step1CreateAppointment({super.key});

  @override
  Step1CreateAppointmentState createState() => Step1CreateAppointmentState();
}

class Step1CreateAppointmentState extends State<Step1CreateAppointment> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  void _next(String zoneId) {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final now = DateTime.now();
    Navigator.pushNamed(
      context,
      '/create_appointment_step_2',
      arguments: Appointment(
        title: _title.text.trim(),
        description: _description.text.trim(),
        zoneId: zoneId,
        availableTimeSlots: [],
        appointmentId: '',
        expirationDate: now.add(const Duration(days: 7)),
        creationDate: now,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deviceTimeZone = context.watch<DeviceTimeZone>();
    final zoneId = deviceTimeZone.zoneId;
    return WizardScaffold(
      step: 1,
      totalSteps: 3,
      appBarTitle: 'create_appointment'.tr(),
      title: 'create_appointment_step1_title'.tr(),
      subtitle: 'create_appointment_step1_subhead'.tr(),
      primaryLabel: 'next'.tr(),
      onPrimary: zoneId == null ? null : () => _next(zoneId),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              label: 'create_appointment_title'.tr(),
              hint: 'create_appointment_hint'.tr(),
              controller: _title,
              icon: Icons.title_rounded,
              textInputAction: TextInputAction.next,
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'create_appointment_title_error'.tr()
                  : null,
            ),
            const SizedBox(height: Spacing.md),
            _DescriptionField(controller: _description),
            const SizedBox(height: Spacing.md),
            Card(
              child: ListTile(
                leading: const Icon(Icons.public_rounded),
                title: Text('appointment_creator_timezone'.tr()),
                subtitle: Text(
                  zoneId ??
                      (deviceTimeZone.error == null
                          ? 'appointment_timezone_loading'.tr()
                          : 'appointment_timezone_error'.tr()),
                ),
                trailing: deviceTimeZone.error == null
                    ? null
                    : IconButton(
                        tooltip: 'retry'.tr(),
                        onPressed: deviceTimeZone.refresh,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DescriptionField extends StatelessWidget {
  const _DescriptionField({required this.controller});

  final TextEditingController controller;

  static const _maxLength = 1000;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'create_appointment_description'.tr().toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Spacing.sm),
        TextFormField(
          controller: controller,
          maxLines: null,
          minLines: 4,
          maxLength: _maxLength,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: 'create_appointment_description_hint'.tr(),
            alignLabelWithHint: true,
          ),
          validator: (value) => (value == null || value.trim().isEmpty)
              ? 'create_appointment_description_error'.tr()
              : null,
        ),
      ],
    );
  }
}
