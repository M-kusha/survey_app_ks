import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

const int maximumStoredProfileImageBytes = 5 * 1024 * 1024;

String profileImagePathFor(String userId) =>
    'profile_images/$userId/avatar.jpg';

final _canonicalProfileImagePath = RegExp(
  r'^profile_images/[^/]{1,128}/avatar[.]jpg$',
);
final _legacyProfileImagePath = RegExp(r'^profile_images/[^/]{1,128}[.]jpg$');

/// Resolves only EchoMeet profile-image objects in the configured Firebase
/// bucket. Legacy Firebase download URLs are parsed into a Storage [Reference]
/// and downloaded through the authenticated SDK; their bearer token is never
/// handed to an HTTP image widget.
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

/// Displays a profile image only after Firebase Storage has authorized and
/// returned its bytes. Put this over an initials/placeholder layer: failures
/// intentionally render nothing so private URLs never become a network-image
/// fallback.
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

  @override
  void initState() {
    super.initState();
    _bytes = loadAuthenticatedProfileImage(widget.storedReference);
  }

  @override
  void didUpdateWidget(covariant AuthenticatedProfileImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storedReference != widget.storedReference ||
        oldWidget.refreshKey != widget.refreshKey) {
      _bytes = loadAuthenticatedProfileImage(widget.storedReference);
    }
  }

  /// Says why nothing was drawn, in debug builds only.
  ///
  /// Rendering nothing on failure is deliberate — a private object must never
  /// fall back to a network image — but it also means every failure looks
  /// identical to "no photo set": a blank avatar over the initials, with no way
  /// to tell a rules denial from an unreachable bucket from a path this build
  /// refuses to resolve. Release builds stay silent; a storage path is not
  /// something to print in front of a user.
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
          // `profileImageReference` refused the stored value: a path outside
          // this bucket, or one that is not an EchoMeet avatar.
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
