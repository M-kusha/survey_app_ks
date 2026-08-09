import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the app's bundled fonts into the test binding.
///
/// Declaring fonts in `pubspec.yaml` is not enough for widget tests: the test
/// binding substitutes a placeholder face for everything, which draws each
/// glyph as a filled rectangle. Goldens taken without this show blocks instead
/// of text, which makes them useless for judging anything visual — they still
/// catch layout regressions, but you cannot see what the screen says.
///
/// Reads the files directly rather than through `rootBundle`, because the asset
/// bundle in a test run does not include fonts.
Future<void> loadAppFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  const families = <String, List<String>>{
    'Inter': [
      'assets/fonts/Inter-Regular.ttf',
      'assets/fonts/Inter-Medium.ttf',
      'assets/fonts/Inter-SemiBold.ttf',
      'assets/fonts/Inter-Bold.ttf',
    ],
    'Space Grotesk': [
      'assets/fonts/SpaceGrotesk-Medium.ttf',
      'assets/fonts/SpaceGrotesk-Bold.ttf',
    ],
  };

  for (final entry in families.entries) {
    final loader = FontLoader(entry.key);
    for (final path in entry.value) {
      final file = File(path);
      if (!file.existsSync()) {
        throw StateError(
          'Missing font asset: $path. Goldens would silently fall back to the '
          'placeholder face and render text as boxes.',
        );
      }
      loader.addFont(
        file.readAsBytes().then((bytes) => ByteData.view(bytes.buffer)),
      );
    }
    await loader.load();
  }

  await _loadMaterialIcons();
}

/// Loads the Material Icons glyph font from the Flutter SDK.
///
/// Icons are a font too, and the test binding substitutes them the same way it
/// substitutes text — every icon renders as a hollow box. The file ships inside
/// the SDK rather than the project, so it is located from the `flutter` binary
/// on PATH.
///
/// Best-effort: a machine where the SDK layout differs still gets readable
/// text, just boxes where the icons are. Failing the whole suite over a
/// decorative glyph would be worse.
Future<void> _loadMaterialIcons() async {
  final flutterRoot = _findFlutterRoot();
  if (flutterRoot == null) return;

  final font = File(
    '$flutterRoot/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
  );
  if (!font.existsSync()) return;

  final loader = FontLoader('MaterialIcons')
    ..addFont(font.readAsBytes().then((b) => ByteData.view(b.buffer)));
  await loader.load();
}

String? _findFlutterRoot() {
  final fromEnv = Platform.environment['FLUTTER_ROOT'];
  if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;

  // `Platform.resolvedExecutable` is the Dart binary inside the SDK:
  // <root>/bin/cache/dart-sdk/bin/dart
  final parts = Platform.resolvedExecutable.replaceAll(r'\', '/').split('/');
  final index = parts.lastIndexOf('bin');
  if (index < 4) return null;
  return parts.sublist(0, index - 3).join('/');
}
