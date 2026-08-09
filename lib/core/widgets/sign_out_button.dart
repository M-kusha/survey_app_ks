import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/login/login.dart';
import 'package:echomeet/login/login_logics.dart';
import 'package:flutter/material.dart';

Future<void> confirmSignOut(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('log_out'.tr()),
      content: Text('log_out_confirm'.tr()),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('cancel'.tr()),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text('log_out'.tr()),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  final signedOut = await AuthManager().signOut();
  if (!context.mounted) return;
  if (!signedOut) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('error_occurred'.tr())));
    return;
  }

  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (context) => const LoginPage()),
    (route) => false,
  );
}

class SignOutOnCompact extends StatelessWidget {
  const SignOutOnCompact({super.key});

  @override
  Widget build(BuildContext context) =>
      context.isCompact ? const SignOutButton() : const SizedBox.shrink();
}

class SignOutButton extends StatelessWidget {
  const SignOutButton({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: 'log_out'.tr(),
      child: Material(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.55),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => confirmSignOut(context),
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Icon(
              Icons.logout_rounded,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
