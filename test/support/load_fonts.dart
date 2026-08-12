import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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

  final parts = Platform.resolvedExecutable.replaceAll(r'\', '/').split('/');
  final index = parts.lastIndexOf('bin');
  if (index < 4) return null;
  return parts.sublist(0, index - 3).join('/');
}
