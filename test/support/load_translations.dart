import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

Future<void> loadAppTranslations({String locale = 'en'}) async {
  final file = File('assets/translations/$locale.json');
  if (!file.existsSync()) {
    throw StateError(
      'Missing ${file.path}. Goldens would render translation keys instead of '
      'copy.',
    );
  }

  final map = json.decode(await file.readAsString()) as Map<String, dynamic>;
  Localization.load(Locale(locale), translations: Translations(map));

  await initializeDateFormatting(locale);
  Intl.defaultLocale = locale;
}
