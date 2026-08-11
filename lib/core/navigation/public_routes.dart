/// Named routes that must remain available without an authenticated session.
abstract final class PublicRoutePaths {
  static const privacyPolicy = '/privacy-policy';
  static const accountDeletion = '/account-deletion';

  /// Where the published legal pages live.
  ///
  /// The full privacy policy is a static page under this origin, not a Flutter
  /// route, so that Google Play and anyone reviewing the app can read it
  /// without installing anything. `functions/src/messaging.ts` opens the same
  /// origin from a notification; a test holds the two in agreement, because a
  /// move to another domain that updated only one of them would leave either
  /// notifications or the policy link pointing at nothing.
  static const canonicalOrigin = 'https://echomeet-app.web.app';

  static const privacyPolicyUrl = '$canonicalOrigin$privacyPolicy';
}
