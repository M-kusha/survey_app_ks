import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const double fontMediumSize = 14;
const double fontMinSize = 12;
const double fontMaxSize = 22;

/// The user's chosen base font size, restored on launch and saved on change.
///
/// Persistence belongs here rather than in the widget that draws the slider.
/// Previously the slider wrote the value to preferences and read it back into
/// its own local state, but nothing ever fed it into this provider at startup —
/// so every launch rendered the whole app at the default size while the slider
/// still displayed the saved number.
class FontSizeProvider with ChangeNotifier {
  FontSizeProvider() {
    _restore();
  }

  static const _key = 'font_size';

  double _fontSize = fontMediumSize;
  double get fontSize => _fontSize;

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
