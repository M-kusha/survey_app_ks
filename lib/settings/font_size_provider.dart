import 'package:flutter/widgets.dart';
import 'package:survey_app_ks/settings/settings.dart';

class FontSizeProvider with ChangeNotifier {
  double _fontSize = fontMediumSize;

  double get fontSize => _fontSize;

  void setFontSize(double fontSize) {
    _fontSize = fontSize;
    notifyListeners();
  }
}
