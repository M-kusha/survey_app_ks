import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/settings/edit_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// A birthdate is stored as a localised display string, not an ISO date — that
/// is what registration has always written. So the edit screen has to read one
/// back to seed its date picker, and it cannot assume the reader's locale is the
/// one the value was written in.
void main() {
  setUpAll(initializeDateFormatting);

  test('a value written in any supported locale reads back', () {
    final birthday = DateTime(1990, 8, 12);

    for (final locale in ['en', 'de', 'sq']) {
      final stored = formatBirthdate(birthday, locale: locale);
      final parsed = parseStoredBirthdate(stored);

      expect(
        parsed,
        birthday,
        reason: '"$stored" (written as $locale) did not read back',
      );
    }
  });

  test('a German value still reads for someone now using English', () {
    // The case that makes this necessary: register in German, switch the app to
    // English, open the edit screen. Guessing here would show the wrong date.
    final stored = formatBirthdate(DateTime(1975, 3, 4), locale: 'de');

    expect(parseStoredBirthdate(stored), DateTime(1975, 3, 4));
  });

  test('a plain ISO value reads too', () {
    expect(parseStoredBirthdate('1988-02-29'), DateTime(1988, 2, 29));
  });

  test('an unreadable or empty value is null rather than a guess', () {
    // Null is a normal outcome and means "open the picker at its default".
    // Inventing a date would silently rewrite someone's birthday on save.
    expect(parseStoredBirthdate(''), isNull);
    expect(parseStoredBirthdate('   '), isNull);
    expect(parseStoredBirthdate('not a date at all'), isNull);
  });

  test('the format written is the format registration writes', () {
    // If these ever diverge, the two screens disagree about what a birthdate
    // looks like and the value stops round-tripping.
    final birthday = DateTime(2000, 1, 31);

    expect(
      formatBirthdate(birthday, locale: 'en'),
      DateFormat.yMMMMd('en').format(birthday),
    );
  });
}
