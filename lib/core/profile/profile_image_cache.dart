import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Keeps avatar bytes so the same photo is fetched from Storage once.
///
/// Without this, every mount of `AuthenticatedProfileImage` was a fresh
/// authenticated download. Rotating the phone rebuilds the shell into a
/// different layout branch, which destroys and recreates those widgets, so
/// turning the device re-downloaded every avatar on screen — repeatedly, on
/// mobile data, for bytes that had not changed.
///
/// Two layers, because they answer different questions:
///
/// * memory — survives rotation, navigation and rebuilds within a session.
/// * disk — survives restarts, so a cold start shows faces without the network.
///
/// Freshness comes from the key, not from expiry. An avatar is immutable for a
/// given revision: uploading a new one increments `profileImageRevision` on the
/// member's document, which changes the key, which misses both layers and
/// fetches. So "only when it is something new" is structural rather than a
/// guess about how long a photo stays current.
class ProfileImageCache {
  ProfileImageCache._();

  /// Total memory the decoded-but-unrendered bytes may occupy.
  ///
  /// Avatars are re-encoded on upload, so they are tens of kilobytes; this is
  /// room for a large member list without being a place memory can quietly grow.
  static const int maxMemoryBytes = 6 * 1024 * 1024;

  /// Insertion-ordered, which is what makes the eviction below least-recent.
  static final Map<String, Uint8List> _memory = <String, Uint8List>{};
  static int _memoryBytes = 0;

  /// In-flight fetches, so a screen mounting twenty rows of the same avatar
  /// issues one request rather than twenty.
  static final Map<String, Future<Uint8List?>> _inFlight = {};

  static Directory? _directory;
  static bool _directoryUnavailable = false;

  /// Set by tests to keep the disk layer out of the way.
  @visibleForTesting
  static bool diskEnabled = !kIsWeb;

  /// A filename-safe key that is identical on every run.
  ///
  /// Deliberately not a hash of the string: `String.hashCode` is not guaranteed
  /// stable across runs, and this key names a file that has to be found again
  /// after a restart. Sanitising is exact, and the reference is already a
  /// bounded Storage path.
  static String keyFor(String storedReference, Object? revision) {
    final safe = storedReference.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final trimmed = safe.length > 120 ? safe.substring(safe.length - 120) : safe;
    return '$trimmed-r${revision ?? 0}';
  }

  /// The cached bytes for this reference and revision, or null if not held.
  static Uint8List? peek(String storedReference, Object? revision) =>
      _memory[keyFor(storedReference, revision)];

  /// Returns the avatar, fetching it only if this exact revision is not held.
  ///
  /// [fetch] is injected so the caller owns the Storage call and this stays a
  /// cache — it has no opinion about authentication.
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

    // Oldest first, which for an insertion-ordered map is least-recently added.
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
      // A cache is an optimisation. If the platform will not give us one, the
      // memory layer still does its job and nothing here should fail a screen.
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
      // Written to a temporary name first: a half-written file that happened to
      // carry the real name would be served as a corrupt image for ever, since
      // the key never changes for a given revision.
      final staging = File('${directory.path}/$key.part');
      await staging.writeAsBytes(bytes, flush: true);
      await staging.rename('${directory.path}/$key');
    } catch (_) {
      // Nothing to do — the memory layer still holds it for this session.
    }
  }

  /// Drops everything. For sign-out, and for tests.
  static Future<void> clear() async {
    _memory.clear();
    _memoryBytes = 0;
    _inFlight.clear();
    final directory = await _cacheDirectory();
    if (directory == null) return;
    try {
      if (directory.existsSync()) directory.deleteSync(recursive: true);
      _directory = null;
    } catch (_) {
      // Leaving stale files behind is harmless: they are keyed by revision, so
      // they can only ever be served for the photo they were written for.
    }
  }
}
