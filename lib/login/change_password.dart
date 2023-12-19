import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  ChangePasswordPageState createState() => ChangePasswordPageState();
}

class ChangePasswordPageState extends State<ChangePasswordPage> {
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  Future<void> _changePassword() async {
    // if (_formKey.currentState?.validate() == true) {
    //   final String newPassword = _newPasswordController.text.trim();
    //   // Assume user is already signed in using Firebase Authentication
    //   User? user = FirebaseAuth.instance.currentUser;

    //   try {
    //     await user?.updatePassword(newPassword);
    //     // Show a success message or navigate the user away from the reset password flow
    //     Navigator.of(context).popUntil((route) => route.isFirst);
    //   } on FirebaseAuthException {
    //     // Handle password update errors here
    //   }
    // }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('set_new_password'.tr()),
        backgroundColor: Colors.blueGrey,
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Card(
              elevation: 5.0, // Card with elevation
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16), // Rounded corners
              ),
              child: Padding(
                padding: const EdgeInsets.all(26.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      const SizedBox(height: 32.0),
                      Text(
                        'enter_new_password'.tr(),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 32.0),
                      TextFormField(
                        controller: _newPasswordController,
                        obscureText: true, // Hide password
                        decoration: InputDecoration(
                          labelText: 'new_password'.tr(),
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'please_enter_new_password'.tr();
                          }
                          if (value.length < 6) {
                            return 'password_must_be_at_least_6_characters'
                                .tr();
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16.0),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: true, // Hide password
                        decoration: InputDecoration(
                          labelText: 'confirm_new_password'.tr(),
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock),
                        ),
                        validator: (value) {
                          if (value != _newPasswordController.text) {
                            return 'passwords_dont_match'.tr();
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24.0),
                      ElevatedButton(
                        onPressed: _changePassword,
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.blueGrey,
                          padding: const EdgeInsets.symmetric(
                              vertical: 16.0, horizontal: 32.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30.0),
                          ),
                        ),
                        child: const Text('change_password').tr(),
                      ),
                      const SizedBox(height: 24.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
