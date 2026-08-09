import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/appointments/appointment_data.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/layout/page_body.dart';
import 'package:echomeet/core/theme/app_colors.dart';
import 'package:echomeet/core/widgets/copyable_code.dart';
import 'package:echomeet/utilities/bottom_navigation.dart';
import 'package:flutter/material.dart';

class Step4CreateAppointment extends StatelessWidget {
  const Step4CreateAppointment({super.key, required this.appointment});

  final Appointment appointment;

  void _finish(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const BottomNavigation(initialIndex: 1),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final app = context.appColors;

    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false),
      body: SafeArea(
        child: PageBody(
          maxWidth: 520,
          centerVertically: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  height: 64,
                  width: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: app.success.withValues(alpha: 0.16),
                    border: Border.all(
                      color: app.success.withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: 32,
                    color: app.success,
                  ),
                ),
              ),
              const SizedBox(height: Spacing.xl),
              Text(
                'appointment_created_successfully'.tr(),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                'share_id_information'.tr(),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Spacing.xl),
              CopyableCode(
                label: 'appointment_id'.tr(),
                code: appointment.appointmentId,
              ),
              const SizedBox(height: Spacing.xl),

              Center(
                child: FilledButton(
                  onPressed: () => _finish(context),
                  child: Text('finish'.tr()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
