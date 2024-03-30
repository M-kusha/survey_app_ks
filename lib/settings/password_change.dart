import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/settings/delete_account.dart';
import 'package:echomeet/utilities/reusable_widgets.dart';
import 'package:echomeet/utilities/text_style.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PasswordChanger extends StatefulWidget {
  final bool isSuperAdmin;
  const PasswordChanger({Key? key, d, required this.isSuperAdmin})
      : super(key: key);

  @override
  PasswordChangertate createState() => PasswordChangertate();
}

class PasswordChangertate extends State<PasswordChanger> {
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  double _strength = 0;
  bool _isPasswordVisible = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    _newPasswordController.addListener(() {
      _updateStrength(_newPasswordController.text);
    });

    _confirmPasswordController.addListener(() {
      setState(() {});
    });
  }

  void _updateStrength(String password) {
    bool hasUppercase = password.contains(RegExp(r'[A-Z]'));
    bool hasLowercase = password.contains(RegExp(r'[a-z]'));
    bool hasDigitsOrSpecialCharacters =
        password.contains(RegExp(r'[\d!@#$%^&*(),.?":{}|<>]'));
    final length = password.length;

    double strength = 0.0;
    if (length >= 3) strength = 0.2;
    if (length > 6) strength = 0.4;
    if (hasUppercase && hasLowercase && length > 6) {
      strength = 0.6;
    }
    if (hasUppercase &&
        hasLowercase &&
        hasDigitsOrSpecialCharacters &&
        length > 6) strength = 1.0;

    setState(() {
      _strength = strength;
    });
  }

  Color _getBorderColorBasedOnStrength(double strength) {
    if (strength <= 0.2) {
      return _newPasswordController.text.isEmpty ? Colors.grey : Colors.red;
    } else if (strength <= 0.4) {
      return Colors.yellow;
    } else if (strength <= 0.6) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }

  Color _getConfirmPasswordBorderColor() {
    bool passwordsMatch =
        _newPasswordController.text == _confirmPasswordController.text &&
            _newPasswordController.text.isNotEmpty;

    return passwordsMatch ? Colors.green : Colors.grey;
  }

  Future<bool> _validateCurrentPassword(String password) async {
    User? user = FirebaseAuth.instance.currentUser;
    String? email = user?.email;

    try {
      var credential =
          EmailAuthProvider.credential(email: email!, password: password);
      var authResult = await user!.reauthenticateWithCredential(credential);
      return authResult.user != null;
    } catch (e) {
      return false;
    }
  }

  void _changePassword() async {
    if (_oldPasswordController.text.isNotEmpty &&
        _newPasswordController.text.isNotEmpty &&
        _confirmPasswordController.text.isNotEmpty &&
        _newPasswordController.text == _confirmPasswordController.text) {
      setState(() {
        _isSaving = true;
      });

      bool isValidOldPassword =
          await _validateCurrentPassword(_oldPasswordController.text);
      if (!isValidOldPassword) {
        if (!context.mounted) return;
        UIUtils.showSnackBar(context, 'invalid_old_password'.tr());
        setState(() {
          _isSaving = false;
        });
        return;
      }

      try {
        User? user = FirebaseAuth.instance.currentUser;
        await user!.updatePassword(_newPasswordController.text);
        if (!context.mounted) return;

        UIUtils.showSnackBar(context, 'password_updated_success'.tr());
        await Future.delayed(const Duration(seconds: 2));
        if (!context.mounted) return;
        Navigator.pop(context);
      } catch (e) {
        if (!context.mounted) return;
        UIUtils.showSnackBar(context, 'An error occurred. Please try again.');
      } finally {
        if (context.mounted) {
          setState(() {
            _isSaving = false;
          });
        }
      }
    } else {
      UIUtils.showSnackBar(context, 'check_your_input'.tr());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text('set_new_password'.tr()),
          centerTitle: true,
          backgroundColor: getAppbarColor(context)),
      body: _isSaving
          ? const Center(
              child: CustomLoadingWidget(
              loadingText: 'saving_password',
            ))
          : SingleChildScrollView(
              child: Center(
                child: Column(
                  children: [
                    Card(
                      shadowColor: getButtonColor(
                          context), // Card with shadow (elevation
                      margin: const EdgeInsets.symmetric(
                          vertical: 50.0, horizontal: 25.0),
                      elevation: 5,
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 20),
                            Padding(
                              padding:
                                  const EdgeInsets.only(left: 8.0, bottom: 8.0),
                              child: Text(
                                'change_password_title'.tr(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 50),
                            TextFormField(
                              controller: _oldPasswordController,
                              obscureText: !_isPasswordVisible,
                              decoration: InputDecoration(
                                labelText: 'old_password'.tr(),
                                border: const OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(12)),
                                ),
                                focusedBorder: const OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(12)),
                                ),
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isPasswordVisible
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isPasswordVisible = !_isPasswordVisible;
                                    });
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _newPasswordController,
                              onChanged: (value) {
                                _updateStrength(value);
                                _newPasswordController.text = value;
                              },
                              obscureText: !_isPasswordVisible,
                              decoration: InputDecoration(
                                labelText: 'set_your_password'.tr(),
                                hintStyle: const TextStyle(
                                  fontSize: 10,
                                ),
                                border: const OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(12)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: const BorderRadius.all(
                                      Radius.circular(12)),
                                  borderSide: BorderSide(
                                    color: _getBorderColorBasedOnStrength(
                                      _strength,
                                    ),
                                    width: 2.0,
                                  ),
                                ),
                                prefixIcon: const Icon(Icons.lock),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isPasswordVisible
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isPasswordVisible = !_isPasswordVisible;
                                    });
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: !_isPasswordVisible,
                              onChanged: (value) {
                                setState(() {});
                              },
                              decoration: InputDecoration(
                                labelText: 'confirm_password'.tr(),
                                border: OutlineInputBorder(
                                  borderRadius: const BorderRadius.all(
                                      Radius.circular(12)),
                                  borderSide: BorderSide(
                                    color: _getConfirmPasswordBorderColor(),
                                    width: 1.0,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: const BorderRadius.all(
                                      Radius.circular(12)),
                                  borderSide: BorderSide(
                                    color: _getConfirmPasswordBorderColor(),
                                    width: 2.0,
                                  ),
                                ),
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isPasswordVisible
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isPasswordVisible = !_isPasswordVisible;
                                    });
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 50),
                          ],
                        ),
                      ),
                    ),
                    DeleteAccountButton(isSuperadmin: widget.isSuperAdmin),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: !_isSaving
          ? buildBottomElevatedButton(
              context: context,
              onPressed: _changePassword,
              buttonText: 'change_password',
            )
          : null,
    );
  }
}
