import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/login/biometrics.dart';
import 'package:echomeet/login/user_preferences.dart';
import 'package:echomeet/settings/settings_kit.dart';
import 'package:flutter/material.dart';

class BiometricOptions extends StatefulWidget {
  const BiometricOptions({super.key, required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  State<BiometricOptions> createState() => _BiometricOptionsState();
}

class _BiometricOptionsState extends State<BiometricOptions> {
  final _auth = AuthService();

  bool _enabled = UserPreferences.getBiometricAuthEnabled();
  bool _available = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkAvailability();
  }

  Future<void> _checkAvailability() async {
    final available =
        await _auth.canCheckBiometrics() && await _auth.isDeviceSupported();
    if (!mounted) return;

    setState(() {
      _available = available;
      _checking = false;

      if (!available && _enabled) {
        _enabled = false;
        UserPreferences.setBiometricAuthEnabled(false);
      }
    });
  }

  Future<void> _set(bool value) async {
    if (value && !await _auth.authenticateUser()) return;

    await UserPreferences.setBiometricAuthEnabled(value);
    if (!mounted) return;
    setState(() => _enabled = value);
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSwitchTile(
      icon: widget.icon,
      title: widget.title,
      subtitle: _checking
          ? null
          : (_available ? null : 'biometrics_unavailable'.tr()),
      value: _enabled,
      onChanged: _checking || !_available ? null : _set,
    );
  }
}
