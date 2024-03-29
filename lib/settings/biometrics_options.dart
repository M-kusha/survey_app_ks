import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:survey_app_ks/login/biometrics.dart';
import 'package:survey_app_ks/login/user_preferences.dart';
import 'package:survey_app_ks/utilities/text_style.dart';

class BiometricOptions extends StatefulWidget {
  final IconData icon;
  final String title;

  const BiometricOptions({
    Key? key,
    required this.icon,
    required this.title,
  }) : super(key: key);

  @override
  State<BiometricOptions> createState() => _BiometricOptionsState();
}

class _BiometricOptionsState extends State<BiometricOptions> {
  bool _biometricEnabled = false;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _loadBiometricSetting();
  }

  Future<void> _loadBiometricSetting() async {
    _biometricEnabled = UserPreferences.getBiometricAuthEnabled() ?? false;
    setState(() {});
  }

  Future<void> _updateBiometricSetting(bool value) async {
    if (value) {
      final canAuthenticate = await _authService.canCheckBiometrics() &&
          await _authService.isDeviceSupported();
      if (canAuthenticate) {
        final didAuthenticate = await _authService.authenticateUser();
        if (didAuthenticate) {
          await UserPreferences.setBiometricAuthEnabled(true);
          _biometricEnabled = true;
        } else {
          _biometricEnabled = false;
          await UserPreferences.setBiometricAuthEnabled(false);
        }
      } else {
        _biometricEnabled = false;
        await UserPreferences.setBiometricAuthEnabled(false);
      }
    } else {
      // Disable biometric
      await UserPreferences.setBiometricAuthEnabled(false);
      _biometricEnabled = false;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    Color buttonColor = getButtonColor(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(widget.icon, size: 24),
              const SizedBox(width: 10),
              Text(
                widget.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Transform.scale(
            scale: 0.7,
            child: CupertinoSwitch(
              activeColor: buttonColor,
              trackColor: Colors.grey,
              value: _biometricEnabled,
              onChanged: (bool newValue) {
                _updateBiometricSetting(newValue);
              },
            ),
          ),
        ],
      ),
    );
  }
}
