import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:echomeet/core/profile/profile_image_sanitizer.dart';
import 'package:echomeet/core/profile/profile_image_upload_error.dart';
import 'package:flutter_test/flutter_test.dart';

class _FunctionError extends FirebaseFunctionsException {
  _FunctionError(String code, String message)
    : super(code: code, message: message);
}

void main() {
  test('maps trusted and local failures to actionable safe copy', () {
    final cases = <Object, String>{
      const InvalidProfileImage(): 'profile_image_invalid',
      _FunctionError('invalid-argument', 'invalid-profile-image'):
          'profile_image_invalid',
      _FunctionError('unauthenticated', 'authentication-required'):
          'profile_image_sign_in_again',
      _FunctionError('failed-precondition', 'email-not-verified'):
          'profile_image_verify_email',
      _FunctionError('aborted', 'stale-profile-image-revision'):
          'profile_image_update_conflict',
      _FunctionError('permission-denied', 'company-banned'):
          'profile_image_account_unavailable',
      _FunctionError('failed-precondition', 'profile-unavailable'):
          'profile_image_account_unavailable',
      _FunctionError('internal', 'sensitive-detail'):
          'error_updating_profile_image',
    };
    for (final entry in cases.entries) {
      expect(profileImageUploadErrorKey(entry.key), entry.value);
    }
  });

  test('every locale has distinct actionable copy', () {
    const keys = {
      'profile_image_invalid',
      'profile_image_sign_in_again',
      'profile_image_verify_email',
      'profile_image_account_unavailable',
      'profile_image_update_conflict',
    };
    for (final locale in ['en', 'de', 'sq']) {
      final copy =
          jsonDecode(
                File('assets/translations/$locale.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      for (final key in keys) {
        expect(copy[key], isA<String>(), reason: '$locale:$key');
        expect(copy[key], isNot(copy['error_updating_profile_image']));
      }
    }
  });
}
