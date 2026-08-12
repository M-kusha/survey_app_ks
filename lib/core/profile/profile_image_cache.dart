import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class ProfileImageCache {
  ProfileImageCache._();

  static const int maxMemoryBytes = 6 * 1024 * 1024;

  static final Map<String, Uint8List> _memory = <String, Uint8List>{};
  static int _memoryBytes = 0;

  static final Map<String, Future<Uint8List?>> _inFlight = {};

  static Directory? _directory;
  static bool _directoryUnavailable = false;

  @visibleForTesting
  static bool diskEnabled = !kIsWeb;

  static String keyFor(String storedReference, Object? revision) {
    final safe = storedReference.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final trimmed = safe.length > 120
        ? safe.substring(safe.length - 120)
        : safe;
    return '$trimmed-r${revision ?? 0}';
  }

  static Uint8List? peek(String storedReference, Object? revision) =>
      _memory[keyFor(storedReference, revision)];

  static Future<Uint8List?> resolve({
    required String storedReference,
    required Object? revision,
    required Future<Uint8List?> Function() fetch,
  }) {
    final key = keyFor(storedReference, revision);

    final remembered = _memory[key];
    if (remembered != null) return Future.value(remembered);

    final pending = _inFlight[key];
    if (pending != null) return pending;

    final request = _resolveUncached(key, fetch).whenComplete(() {
      _inFlight.remove(key);
    });
    _inFlight[key] = request;
    return request;
  }

  static Future<Uint8List?> _resolveUncached(
    String key,
    Future<Uint8List?> Function() fetch,
  ) async {
    final stored = await _readFromDisk(key);
    if (stored != null) {
      _remember(key, stored);
      return stored;
    }

    final fetched = await fetch();
    if (fetched != null && fetched.isNotEmpty) {
      _remember(key, fetched);
      await _writeToDisk(key, fetched);
    }
    return fetched;
  }

  static void _remember(String key, Uint8List bytes) {
    if (bytes.lengthInBytes > maxMemoryBytes) return;

    _memory.remove(key);
    _memory[key] = bytes;
    _memoryBytes += bytes.lengthInBytes;

    while (_memoryBytes > maxMemoryBytes && _memory.isNotEmpty) {
      final oldest = _memory.keys.first;
      _memoryBytes -= _memory.remove(oldest)!.lengthInBytes;
    }
  }

  static Future<Directory?> _cacheDirectory() async {
    if (!diskEnabled || _directoryUnavailable) return null;
    if (_directory != null) return _directory;
    try {
      final base = await getApplicationCacheDirectory();
      final directory = Directory('${base.path}/profile_images');
      if (!directory.existsSync()) directory.createSync(recursive: true);
      _directory = directory;
      return directory;
    } catch (_) {
      _directoryUnavailable = true;
      return null;
    }
  }

  static Future<Uint8List?> _readFromDisk(String key) async {
    final directory = await _cacheDirectory();
    if (directory == null) return null;
    try {
      final file = File('${directory.path}/$key');
      if (!file.existsSync()) return null;
      final bytes = await file.readAsBytes();
      return bytes.isEmpty ? null : bytes;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeToDisk(String key, Uint8List bytes) async {
    final directory = await _cacheDirectory();
    if (directory == null) return;
    try {
      final staging = File('${directory.path}/$key.part');
      await staging.writeAsBytes(bytes, flush: true);
      await staging.rename('${directory.path}/$key');
    } catch (_) {}
  }

  static Future<void> clear() async {
    _memory.clear();
    _memoryBytes = 0;
    _inFlight.clear();
    final directory = await _cacheDirectory();
    if (directory == null) return;
    try {
      if (directory.existsSync()) directory.deleteSync(recursive: true);
      _directory = null;
    } catch (_) {}
  }
}
