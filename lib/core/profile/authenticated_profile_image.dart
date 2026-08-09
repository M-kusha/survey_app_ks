import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
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
    this.userId,
  });

  final String storedReference;
  final BoxFit fit;
  final Object? refreshKey;
  final String? userId;

  @override
  State<AuthenticatedProfileImage> createState() =>
      _AuthenticatedProfileImageState();
}

class _AuthenticatedProfileImageState extends State<AuthenticatedProfileImage> {
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _memberStream;

  @override
  void initState() {
    super.initState();
    _memberStream = _streamFor(widget.userId);
  }

  @override
  void didUpdateWidget(covariant AuthenticatedProfileImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _memberStream = _streamFor(widget.userId);
    }
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>>? _streamFor(
    String? userId,
  ) {
    final id = userId?.trim() ?? '';
    if (id.isEmpty) return null;
    return FirebaseFirestore.instance
        .collection('memberDirectory')
        .doc(id)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final memberStream = _memberStream;
    if (memberStream == null) {
      return _AuthenticatedProfileImageBytes(
        storedReference: widget.storedReference,
        fit: widget.fit,
        refreshKey: widget.refreshKey,
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: memberStream,
      builder: (context, snapshot) {
        final member = snapshot.data?.data();
        final storedReference = member == null
            ? widget.storedReference
            : member['profileImage'] as String? ?? '';
        final refreshKey = member == null
            ? widget.refreshKey
            : member['profileImageRevision'] ?? 0;
        return _AuthenticatedProfileImageBytes(
          storedReference: storedReference,
          fit: widget.fit,
          refreshKey: refreshKey,
        );
      },
    );
  }
}

class _AuthenticatedProfileImageBytes extends StatefulWidget {
  const _AuthenticatedProfileImageBytes({
    required this.storedReference,
    required this.fit,
    required this.refreshKey,
  });

  final String storedReference;
  final BoxFit fit;
  final Object? refreshKey;

  @override
  State<_AuthenticatedProfileImageBytes> createState() =>
      _AuthenticatedProfileImageBytesState();
}

class _AuthenticatedProfileImageBytesState
    extends State<_AuthenticatedProfileImageBytes> {
  late Future<Uint8List?> _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = loadAuthenticatedProfileImage(widget.storedReference);
  }

  @override
  void didUpdateWidget(covariant _AuthenticatedProfileImageBytes oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storedReference != widget.storedReference ||
        oldWidget.refreshKey != widget.refreshKey) {
      _bytes = loadAuthenticatedProfileImage(widget.storedReference);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _bytes,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null || bytes.isEmpty) return const SizedBox.shrink();
        return Image.memory(
          bytes,
          fit: widget.fit,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
        );
      },
    );
  }
}
