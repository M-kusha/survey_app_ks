import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/login/login.dart';
import 'package:echomeet/settings/account_deletion_service.dart';
import 'package:echomeet/utilities/reusable_widgets.dart';
import 'package:flutter/material.dart';

/// Permanently deletes the signed-in user's account.
///
/// Disabled for superadmins: a company's owner cannot delete themselves and
/// leave the company without one.
class DeleteAccountButton extends StatefulWidget {
  const DeleteAccountButton({super.key, required this.isSuperadmin});

  final bool isSuperadmin;

  @override
  State<DeleteAccountButton> createState() => _DeleteAccountButtonState();
}

class _DeleteAccountButtonState extends State<DeleteAccountButton> {
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.isSuperadmin || _isDeleting;
    return SizedBox(
      width: 200,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: disabled ? Colors.grey : Colors.red,
        ),
        onPressed: disabled ? null : _confirmAndDelete,
        child: _isDeleting
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                'delete_account'.tr(),
                style: TextStyle(color: disabled ? Colors.black : Colors.white),
              ),
      ),
    );
  }

  Future<void> _confirmAndDelete() async {
    final password = await _promptForPassword();
    if (password == null || !mounted) return;

    setState(() => _isDeleting = true);

    try {
      await AccountDeletionService().deleteAccount(password: password);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    } on ReauthenticationFailure {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      UIUtils.showSnackBar(context, 'invalid_old_password'.tr());
    } catch (_) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      UIUtils.showSnackBar(context, 'error_occurred'.tr());
    }
  }

  /// Confirms intent and collects the password Firebase needs to re-authenticate
  /// before it will delete an account.
  ///
  /// Returns null if the user backs out.
  Future<String?> _promptForPassword() {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('confirm'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('delete_account_warning'.tr()),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'password_label'.tr(),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text(
              'delete'.tr(),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }
}
