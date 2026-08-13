import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const double fontMediumSize = 14;
const double fontMinSize = 12;
const double fontMaxSize = 22;

class FontSizeProvider with ChangeNotifier {
  FontSizeProvider() {
    _restore();
  }

  static const _key = 'font_size';

  double _fontSize = fontMinSize;
  double get fontSize => _fontSize;

  double get textScale => _fontSize / fontMediumSize;

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(_key);
    if (saved == null || saved == _fontSize) return;
    _fontSize = saved.clamp(fontMinSize, fontMaxSize);
    notifyListeners();
  }

  Future<void> setFontSize(double fontSize) async {
    final clamped = fontSize.clamp(fontMinSize, fontMaxSize);
    if (clamped == _fontSize) return;

    _fontSize = clamped;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_key, clamped);
  }
}
