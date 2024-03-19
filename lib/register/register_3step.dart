import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:password_strength/password_strength.dart';
import 'package:survey_app_ks/register/registered_sucesfully.dart';
import 'package:survey_app_ks/register/register_4step.dart';
import 'package:survey_app_ks/utilities/colors.dart';
import 'package:survey_app_ks/register/register_logics.dart';
import 'package:survey_app_ks/utilities/reusable_widgets.dart';

class Register3step extends StatefulWidget {
  final RegisterLogic registerLogic;
  final ProfileType profileType;
  final String? companyId;

  const Register3step(
      {Key? key,
      required this.registerLogic,
      required this.profileType,
      this.companyId})
      : super(key: key);

  @override
  Register3stepState createState() => Register3stepState();
}

class Register3stepState extends State<Register3step> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  double _strength = 0;
  bool _isPasswordVisible = false;
  final double _minPasswordStrength = 0.3;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
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
      return Colors.red;
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
        _passwordController.text == _confirmPasswordController.text &&
            _passwordController.text.isNotEmpty;

    return passwordsMatch ? Colors.green : Colors.grey;
  }

  void _onPressed() {
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (password.isEmpty || confirmPassword.isEmpty) {
      UIUtils.showSnackBar(context, 'password_empty'.tr());
      return;
    }

    if (password != confirmPassword) {
      UIUtils.showSnackBar(context, 'passwords_dont_match'.tr());
      return;
    }

    final passwordStrength = estimatePasswordStrength(password);
    if (passwordStrength < _minPasswordStrength) {
      UIUtils.showSnackBar(context, 'set_secure_password'.tr());

      return;
    }

    widget.registerLogic.passwordController.text = password;

    if (widget.profileType == ProfileType.company) {
      _finishRegistration();
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              Register4step(registerLogic: widget.registerLogic),
        ),
      ).then((_) {
        if (widget.registerLogic.selectedCompanyName != null) {
          _finishRegistration();
        }
      });
    }
  }

  void _finishRegistration() async {
    setState(() {
      _isSaving = true;
    });

    try {
      await widget.registerLogic.registerUser(companyId: widget.companyId);
      if (!context.mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
            builder: (context) => const RegistrationSuccessPage()),
        (Route<dynamic> route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        UIUtils.showSnackBar(context, 'email_already_exists'.tr());
      } else {
        UIUtils.showSnackBar(context, 'Registration failed: ${e.message}');
      }
    } catch (e) {
      UIUtils.showSnackBar(context, 'An unexpected error occurred.');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('set_your_password'.tr()),
        centerTitle: true,
        backgroundColor: ThemeBasedAppColors.getColor(context, 'appbarColor'),
      ),
      body: _isSaving
          ? const Center(
              child: CustomLoadingWidget(
              loadingText: 'saving_regisration',
            ))
          : Center(
              child: Card(
                shadowColor:
                    ThemeBasedAppColors.getColor(context, 'buttonColor'),
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
                        padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                        child: Text(
                          'secure_password'.tr(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 50),
                      TextFormField(
                        controller: _passwordController,
                        onChanged: (value) {
                          _updateStrength(value);
                          widget.registerLogic.passwordController.text = value;
                        },
                        obscureText: !_isPasswordVisible,
                        decoration: InputDecoration(
                          labelText: 'set_your_password'.tr(),
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          enabledBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius:
                                const BorderRadius.all(Radius.circular(12)),
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
                            borderRadius:
                                const BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(
                              color: _getConfirmPasswordBorderColor(),
                              width: 1.0,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius:
                                const BorderRadius.all(Radius.circular(12)),
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
            ),
      bottomNavigationBar: !_isSaving
          ? buildBottomElevatedButton(
              context: context,
              onPressed: _onPressed,
              buttonText: widget.profileType == ProfileType.company
                  ? 'finish_registration'
                  : 'next',
            )
          : null,
    );
  }
}
