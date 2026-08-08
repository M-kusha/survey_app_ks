import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/utilities/text_style.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Starts Firebase's password reset.
///
/// Firebase emails the user a **link**; they set the new password in the
/// browser and then sign in again here. There is no in-app code to type and no
/// in-app "set new password" form — earlier builds showed both, but the code
/// was never verified and the new password was never applied, so a user could
/// walk the whole flow and end up with their old password unchanged.
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isSending = false;
  bool _linkSent = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSending = true;
      _error = null;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _linkSent = true);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      // A malformed address is the user's own typo and worth pointing out.
      // Everything else — including 'user-not-found' — reports success, so this
      // screen cannot be used to discover which addresses have accounts.
      setState(() {
        if (e.code == 'invalid-email') {
          _error = 'invalid_email_message'.tr();
        } else {
          _linkSent = true;
        }
      });
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('reset_password'.tr()),
        backgroundColor: getAppbarColor(context),
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                elevation: 5.0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: _linkSent ? _buildConfirmation() : _buildForm(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'reset_password'.tr(),
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24.0),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _sendResetLink(),
            decoration: InputDecoration(
              labelText: 'email'.tr(),
              hintText: 'enter_email'.tr(),
              errorText: _error,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: const Icon(Icons.email),
            ),
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'invalid_email_message'.tr()
                : null,
          ),
          const SizedBox(height: 24.0),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSending ? null : _sendResetLink,
              style: ElevatedButton.styleFrom(
                foregroundColor: getTextColor(context),
                backgroundColor: getButtonColor(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30.0),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16.0),
              ),
              child: _isSending
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('send_reset_link'.tr()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmation() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.mark_email_read_outlined,
          size: 56,
          color: getButtonColor(context),
        ),
        const SizedBox(height: 16),
        Text(
          'reset_link_sent'.tr(),
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'reset_link_sent_body'.tr(
            namedArgs: {'email': _emailController.text.trim()},
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              foregroundColor: getTextColor(context),
              backgroundColor: getButtonColor(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30.0),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16.0),
            ),
            child: Text('back_to_login'.tr()),
          ),
        ),
      ],
    );
  }
}
