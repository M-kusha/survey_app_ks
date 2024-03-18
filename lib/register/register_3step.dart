import 'package:easy_localization/easy_localization.dart';
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

  @override
  void initState() {
    super.initState();
  }

  void _updateStrength(String password) {
    double strength = 0.0;
    final length = password.length;

    bool hasUppercase = password.contains(RegExp(r'[A-Z]'));
    bool hasLowercase = password.contains(RegExp(r'[a-z]'));
    bool hasDigits = password.contains(RegExp(r'\d'));
    bool hasSpecialCharacters =
        password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

    if (length > 6) strength += 0.2;
    if (hasUppercase) strength += 0.2;
    if (hasLowercase) strength += 0.2;
    if (hasDigits) strength += 0.2;
    if (hasSpecialCharacters) strength += 0.2;

    setState(() {
      _strength = strength.clamp(0.0, 1.0);
    });
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

    // Check password strength
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
    try {
      await widget.registerLogic.registerUser(companyId: widget.companyId);

      if (!context.mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
            builder: (context) => const RegistrationSuccessPage()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      UIUtils.showSnackBar(context, 'Registration failed: $e');
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
      body: Center(
        child: Card(
          margin: const EdgeInsets.symmetric(vertical: 50.0, horizontal: 25.0),
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
                _buildStrengthIndicator(_strength),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'confirm_password'.tr(),
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
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
      bottomNavigationBar: buildBottomElevatedButton(
        context: context,
        onPressed: _onPressed,
        buttonText:
            widget.profileType == ProfileType.company ? 'finish' : 'next',
      ),
    );
  }

  Widget _buildStrengthIndicator(double strength) {
    Color color;
    if (strength <= 0.2) {
      color = Colors.red;
    } else if (strength <= 0.4) {
      color = Colors.orange;
    } else if (strength <= 0.6) {
      color = Colors.yellow;
    } else if (strength <= 0.8) {
      color = Colors.lightGreen;
    } else {
      color = Colors.green;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (index) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 2.0),
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: index < (_strength * 5).ceil() ? color : Colors.grey,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
