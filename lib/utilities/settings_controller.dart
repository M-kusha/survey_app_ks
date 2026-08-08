import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

// Font size lives in FontSizeProvider, which owns both the value and its
// persistence. It used to be duplicated here as well, which is how the app and
// the settings slider ended up disagreeing about the current size.
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
