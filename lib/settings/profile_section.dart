import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/profile/authenticated_profile_image.dart';
import 'package:echomeet/core/profile/profile_image_sanitizer.dart';
import 'package:echomeet/core/profile/profile_image_revision.dart';
import 'package:echomeet/core/profile/profile_image_upload_error.dart';
import 'package:echomeet/core/theme/app_theme.dart';
import 'package:echomeet/core/widgets/feature_kit.dart';
import 'package:echomeet/settings/edit_profile.dart';
import 'package:echomeet/utilities/reusable_widgets.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ProfileSection extends StatefulWidget {
  const ProfileSection({super.key, required this.userId});

  final String userId;

  @override
  State<ProfileSection> createState() => _ProfileSectionState();
}

class _ProfileSectionState extends State<ProfileSection> {
  bool _uploading = false;
  int _avatarRevision = 0;

  Stream<DocumentSnapshot> get _user => FirebaseFirestore.instance
      .collection('users')
      .doc(widget.userId)
      .snapshots();

  Future<void> _pickAndUpload(int? expectedRevision) async {
    if (expectedRevision == null) {
      UIUtils.showSnackBar(
        context,
        'profile_image_account_unavailable'.tr(),
        isError: true,
      );
      return;
    }

    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 90,
    );
    if (picked == null || !mounted) return;

    setState(() => _uploading = true);

    try {
      final bytes = await sanitizeProfileImage(picked);
      final result = await FirebaseFunctions.instanceFor(region: 'europe-west4')
          .httpsCallable('uploadProfileImage')
          .call<Map<String, dynamic>>({
            'jpegBase64': base64Encode(bytes),
            'expectedRevision': expectedRevision,
          });
      if (result.data['path'] != profileImagePathFor(widget.userId)) {
        throw StateError('Unexpected profile image path.');
      }
      final revision = result.data['revision'];
      if (revision is! int || revision != expectedRevision + 1) {
        throw StateError('Unexpected profile image revision.');
      }

      if (!mounted) return;
      setState(() => _avatarRevision = revision);
      UIUtils.showSnackBar(context, 'profile_image_uploaded'.tr());
    } catch (error) {
      if (!mounted) return;
      UIUtils.showSnackBar(
        context,
        profileImageUploadErrorKey(error).tr(),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return StreamBuilder<DocumentSnapshot>(
      stream: _user,
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final name = data?['fullName'] as String?;
        final email = data?['email'] as String?;

        final stored = (data?['profileImage'] as String?)?.trim();
        final image = (stored == null || stored.isEmpty) ? null : stored;
        final validatedRevision = data == null
            ? null
            : validatedProfileImageRevision(data['profileImageRevision']);
        final profileImageRevision = validatedRevision ?? 0;
        final role = data?['role'] as String?;

        return Container(
          padding: const EdgeInsets.all(Spacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: scheme.surfaceContainerLow,
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.7),
            ),
          ),
          child: Row(
            children: [
              _Avatar(
                url: image,
                uploading: _uploading,
                initials: _initialsOf(name),
                onTap: () => _pickAndUpload(validatedRevision),
                avatarRevision: _avatarRevision,
                profileImageRevision: profileImageRevision,
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name ?? 'loading'.tr(),
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (email != null)
                      Text(
                        email,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (role != null) ...[
                      const SizedBox(height: Spacing.sm),
                      _RoleBadge(role: role),
                    ],
                  ],
                ),
              ),

              CircleAction(
                icon: Icons.edit_outlined,
                tooltip: 'edit_profile'.tr(),
                onTap: () => _editProfile(),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editProfile() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfilePage(userId: widget.userId),
      ),
    );
  }

  static String _initialsOf(String? name) {
    final parts = (name ?? '').trim().split(RegExp(r'\s+'))
      ..removeWhere((part) => part.isEmpty);
    if (parts.isEmpty) return '?';
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.url,
    required this.uploading,
    required this.initials,
    required this.onTap,
    required this.avatarRevision,
    required this.profileImageRevision,
  });

  final String? url;
  final bool uploading;
  final String initials;
  final VoidCallback onTap;
  final int avatarRevision;
  final int profileImageRevision;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InkWell(
      onTap: uploading ? null : onTap,
      customBorder: const CircleBorder(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipOval(
            child: Container(
              height: 56,
              width: 56,
              color: scheme.primaryContainer,
              alignment: Alignment.center,

              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: Text(
                      initials,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  if (url case final storedReference?)
                    AuthenticatedProfileImage(
                      storedReference: storedReference,
                      refreshKey: (profileImageRevision, avatarRevision),
                    ),
                ],
              ),
            ),
          ),
          if (uploading)
            const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          if (!uploading)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.surfaceContainerLow,
                ),
                child: Icon(
                  Icons.photo_camera_rounded,
                  size: 13,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isAdmin = role == 'superadmin' || role == 'admin';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.full),
        color: isAdmin
            ? scheme.primary.withValues(alpha: 0.14)
            : scheme.surfaceContainerHighest,
      ),
      child: Text(
        'role_$role'.tr(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: isAdmin ? scheme.primary : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
