import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/layout/page_body.dart';
import 'package:echomeet/core/theme/app_colors.dart';
import 'package:echomeet/core/widgets/aurora_background.dart';
import 'package:echomeet/core/widgets/glass_panel.dart';
import 'package:flutter/material.dart';

class RegistrationSuccessPage extends StatefulWidget {
  const RegistrationSuccessPage({super.key});

  @override
  RegistrationSuccessPageState createState() => RegistrationSuccessPageState();
}

class RegistrationSuccessPageState extends State<RegistrationSuccessPage> {
  static const _seconds = 5;

  int _remaining = _seconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining > 1) {
        setState(() => _remaining--);
        return;
      }
      _goToLogin();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _goToLogin() {
    _timer?.cancel();
    _timer = null;
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = context.appColors;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AuroraBackground(
        child: SafeArea(
          child: PageBody(
            maxWidth: 460,
            centerVertically: true,
            child: GlassPanel(
              padding: const EdgeInsets.all(Spacing.xxl),
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
                    'registration_success'.tr(),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: Spacing.sm),
                  Text(
                    '${'you_will_be_redirected'.tr()} $_remaining '
                    '${'registration_seconds'.tr()}.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: Spacing.xl),
                  GlowButton(
                    onPressed: _goToLogin,
                    label: 'back_to_login'.tr(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
