import 'package:flutter/widgets.dart';

abstract final class AppLocales {
  static const names = <String, String>{
    'en': 'English',
    'de': 'Deutsch',
    'sq': 'Shqip',
  };

  static const fallback = Locale('en', '');

  static const supported = <Locale>[
    Locale('en', ''),
    Locale('de', ''),
    Locale('sq', ''),
  ];

  static const path = 'assets/translations';
}
