import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsController {
  void saveThemeBool(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLight', value);
  }

  Future<bool> getThemeBool() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLight') ?? false;
  }
}
