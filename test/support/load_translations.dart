import 'dart:convert';
import 'dart:io';

// Neither of these is exported from the package barrel, so they are reached
// directly. That is a deliberate test-only coupling: the alternative is
// standing up the whole `EasyLocalization` widget just to read a JSON file.
import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Primes easy_localization so `'key'.tr()` returns real copy in tests.
///
/// Without it every call falls through to the key itself, so goldens read
/// "login_headline" where the headline should be — which makes them useless for
/// judging type and line breaks, the exact thing a golden is for.
///
/// This skips the `EasyLocalization` widget on purpose. That widget loads
/// assets through `rootBundle` and drives its own async init, which a widget
/// test would have to pump through; the file is right there on disk, and
/// [Localization.load] is the same static the widget ends up calling.
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

  // Dates are part of the translation. Without these two lines every
  // `DateFormat` in the app falls back to en_US, so a German golden would show
  // German copy next to English weekdays and miss exactly the bug this is
  // meant to demonstrate.
  await initializeDateFormatting(locale);
  Intl.defaultLocale = locale;
}
