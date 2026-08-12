import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class NotificationLocaleService {
  NotificationLocaleService._();

  static const _supported = {'en', 'de', 'sq'};
  static Future<void> _queue = Future<void>.value();
  static StreamSubscription<User?>? _authSubscription;
  static Locale? _desiredLocale;
  static String? _lastSynced;

  static void observe(Locale locale) {
    _desiredLocale = locale;
    _authSubscription ??= FirebaseAuth.instance.authStateChanges().listen((
      user,
    ) {
      if (user == null) {
        _lastSynced = null;
        return;
      }
      final desired = _desiredLocale;
      if (user.emailVerified && desired != null) syncBestEffort(desired);
    });
    syncBestEffort(locale);
  }

  static void syncBestEffort(Locale locale) {
    final previous = _queue;
    _queue = () async {
      try {
        await previous;
      } catch (_) {}

      final user = FirebaseAuth.instance.currentUser;
      if (user == null || !user.emailVerified) return;

      final languageCode = _supported.contains(locale.languageCode)
          ? locale.languageCode
          : 'en';
      final target = '${user.uid}:$languageCode';
      if (_lastSynced == target) return;

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'notificationLocale': languageCode},
      );
      _lastSynced = target;
    }();

    unawaited(
      _queue.catchError((error) {
        if (kDebugMode) {
          debugPrint('Notification language could not be synced: $error');
        }
      }),
    );
  }
}
