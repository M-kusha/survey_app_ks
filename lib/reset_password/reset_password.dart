import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:survey_app_ks/utilities/colors.dart';

import 'error_reset.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  ResetPasswordPageState createState() => ResetPasswordPageState();
}

class ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _resetPassword() async {
    final String email = _emailController.text.trim();
    final BuildContext currentContext = context; // Get the current BuildContext

    try {
      await _auth.sendPasswordResetEmail(email: email);

      if (mounted) {
        builResetPasswordVerificationPage(currentContext);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String title = '';
        String message = '';

        if (e.code == 'user-not-found') {
          title = 'user_not_found'.tr();
          message = 'check_email_again'.tr();
        } else {
          title = 'Error';
          message = 'unexpected_error'.tr();
        }
        showErrorDialog(currentContext, title, message);
      }
    }
  }

  void showErrorDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) {
        return ErrorDialog(
          title: title,
          message: message,
        );
      },
    );
  }

  void builResetPasswordVerificationPage(BuildContext context) {
    Navigator.pushNamed(context, '/ResetPasswordVerificationPage');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('reset_password'.tr()),
        backgroundColor: ThemeBasedAppColors.getColor(context, 'appbarColor'),
        elevation: 0, // Flat design for the app bar
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(height: MediaQuery.of(context).size.height * 0.2),

              Card(
                elevation: 5.0, // Card with elevation
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16), // Rounded corners
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: <Widget>[
                      const SizedBox(height: 24.0),
                      Text(
                        'reset_password'.tr(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24.0),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'email'.tr(),
                          hintText: 'enter_email'.tr(),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.email),
                          prefixIconColor: Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(height: 32.0),
                      ElevatedButton(
                        onPressed: _resetPassword,
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.blueGrey, // Text color
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30.0),
                          ),
                          padding: const EdgeInsets.symmetric(
                              vertical: 16.0, horizontal: 32.0),
                          elevation: 0,
                        ),
                        child: const Text('send_reset_code').tr(),
                      ),

                      const SizedBox(height: 16.0),
                      // or go back to login page
                    ],
                  ),
                ),
              ),
              // Additional Widgets if needed
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }
}
