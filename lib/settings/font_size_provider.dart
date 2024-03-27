import 'package:flutter/widgets.dart';

const double fontMediumSize = 14;

class FontSizeProvider with ChangeNotifier {
  double _fontSize = fontMediumSize;

  double get fontSize => _fontSize;

  void setFontSize(double fontSize) {
    _fontSize = fontSize;
    notifyListeners();
  }
}
