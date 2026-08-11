import 'package:cloud_functions/cloud_functions.dart';
import 'package:echomeet/core/profile/profile_image_sanitizer.dart';

class ProfileImageUploadResult {
  const ProfileImageUploadResult.success() : errorKey = null;
  const ProfileImageUploadResult.failed(this.errorKey);

  final String? errorKey;
  bool get succeeded => errorKey == null;
}

String profileImageUploadErrorKey(Object error) {
  if (error is InvalidProfileImage) return 'profile_image_invalid';
  if (error is! FirebaseFunctionsException) {
    return 'error_updating_profile_image';
  }
  final message = error.message;
  if (error.code == 'unauthenticated' || message == 'authentication-required') {
    return 'profile_image_sign_in_again';
  }
  if (message == 'email-not-verified') return 'profile_image_verify_email';
  if (error.code == 'invalid-argument') return 'profile_image_invalid';
  if (error.code == 'aborted' || message == 'stale-profile-image-revision') {
    return 'profile_image_update_conflict';
  }
  if (error.code == 'permission-denied' ||
      error.code == 'failed-precondition') {
    return 'profile_image_account_unavailable';
  }
  return 'error_updating_profile_image';
}
