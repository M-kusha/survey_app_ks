import 'package:echomeet/settings/font_size_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a fresh install starts at the smallest size', () {
    expect(FontSizeProvider().fontSize, fontMinSize);
    expect(fontMinSize, 12);
  });

  test('a saved size still wins over the default', () async {
    SharedPreferences.setMockInitialValues({'font_size': 18.0});
    final provider = FontSizeProvider();
    await Future<void>.delayed(Duration.zero);

    expect(provider.fontSize, 18);
  });

  test('the scale is relative to the medium size, not the default', () {
    expect(FontSizeProvider().textScale, fontMinSize / fontMediumSize);
  });
}
