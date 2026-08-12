import 'dart:typed_data';

import 'package:echomeet/core/profile/profile_image_cache.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

const int maximumStoredProfileImageBytes = 5 * 1024 * 1024;

String profileImagePathFor(String userId) =>
    'profile_images/$userId/avatar.jpg';

final _canonicalProfileImagePath = RegExp(
  r'^profile_images/[^/]{1,128}/avatar[.]jpg$',
);
final _legacyProfileImagePath = RegExp(r'^profile_images/[^/]{1,128}[.]jpg$');

Reference? profileImageReference(String stored, {FirebaseStorage? storage}) {
  final value = stored.trim();
  if (value.isEmpty) return null;

  final instance = storage ?? FirebaseStorage.instance;
  try {
    final reference =
        value.startsWith('gs://') ||
            value.startsWith('http://') ||
            value.startsWith('https://')
        ? instance.refFromURL(value)
        : instance.ref(value);

    final isSupportedPath =
        _canonicalProfileImagePath.hasMatch(reference.fullPath) ||
        _legacyProfileImagePath.hasMatch(reference.fullPath);
    if (!isSupportedPath || reference.bucket != instance.bucket) return null;
    return reference;
  } catch (_) {
    return null;
  }
}

Future<Uint8List?> loadAuthenticatedProfileImage(
  String stored, {
  FirebaseStorage? storage,
}) async {
  final reference = profileImageReference(stored, storage: storage);
  if (reference == null) return null;
  return reference.getData(maximumStoredProfileImageBytes);
}

class AuthenticatedProfileImage extends StatefulWidget {
  const AuthenticatedProfileImage({
    super.key,
    required this.storedReference,
    this.fit = BoxFit.cover,
    this.refreshKey,
  });

  final String storedReference;
  final BoxFit fit;
  final Object? refreshKey;

  @override
  State<AuthenticatedProfileImage> createState() =>
      _AuthenticatedProfileImageState();
}

class _AuthenticatedProfileImageState extends State<AuthenticatedProfileImage> {
  late Future<Uint8List?> _bytes;

  Future<Uint8List?> _load() => ProfileImageCache.resolve(
    storedReference: widget.storedReference,
    revision: widget.refreshKey,
    fetch: () => loadAuthenticatedProfileImage(widget.storedReference),
  );

  @override
  void initState() {
    super.initState();
    _bytes = _load();
  }

  @override
  void didUpdateWidget(covariant AuthenticatedProfileImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storedReference != widget.storedReference ||
        oldWidget.refreshKey != widget.refreshKey) {
      _bytes = _load();
    }
  }

  void _explain(Object reason) {
    assert(() {
      debugPrint(
        'EchoMeet: profile image not shown for "${widget.storedReference}" — '
        '$reason',
      );
      return true;
    }());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _bytes,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        if (snapshot.error case final error?) {
          _explain(error);
          return const SizedBox.shrink();
        }
        final bytes = snapshot.data;
        if (bytes == null) {
          _explain('the stored reference did not resolve to an avatar object');
          return const SizedBox.shrink();
        }
        if (bytes.isEmpty) {
          _explain('the stored object is empty');
          return const SizedBox.shrink();
        }
        return Image.memory(
          bytes,
          fit: widget.fit,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) {
            _explain('the bytes are not a decodable image ($error)');
            return const SizedBox.shrink();
          },
        );
      },
    );
  }
}
