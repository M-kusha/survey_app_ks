import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:survey_app_ks/settings/font_size_provider.dart';

class SettingsController {
  Future<double> getFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('font_size') ?? fontMediumSize;
  }

  Future<void> saveFontSize(double size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('font_size', size);
  }

  void saveThemeBool(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLight', value);
  }

  Future<bool> getThemeBool() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLight') ?? false;
  }
}
