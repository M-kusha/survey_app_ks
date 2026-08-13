import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:echomeet/core/notifications/notification_navigation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PushStartResult { registered, disabled, unavailable }

class PushCleanupException implements Exception {
  const PushCleanupException(this.startError, this.cleanupError);

  final Object? startError;
  final Object cleanupError;

  @override
  String toString() => 'Push cleanup failed: $cleanupError';
}

class PushService {
  factory PushService({FirebaseFirestore? firestore, FirebaseAuth? auth}) {
    if (firestore != null || auth != null) {
      return PushService._(firestore: firestore, auth: auth);
    }
    return _instance;
  }

  PushService._({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  static final PushService _instance = PushService._();

  static const notificationsPreferenceKey = 'notificationsEnabled';
  static const _webVapidKey = String.fromEnvironment('FCM_WEB_VAPID_KEY');

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final _local = FlutterLocalNotificationsPlugin();

  StreamSubscription<String>? _tokenRefresh;
  StreamSubscription<RemoteMessage>? _foreground;
  StreamSubscription<RemoteMessage>? _opened;
  StreamSubscription<User?>? _authentication;
  bool _localInitialised = false;

  Future<PushStartResult>? _startInFlight;
  String? _startInFlightUid;
  String? _registeredUid;
  String? _registeredToken;
  String? _refreshOwnerUid;
  String? _pendingRefreshToken;
  Future<void>? _refreshWrite;
  Timer? _refreshRetry;
  int _refreshRetryAttempt = 0;
  Timer? _cleanupRetry;
  int _cleanupRetryAttempt = 0;
  int _cleanupGeneration = 0;
  bool _cleanupPending = false;
  String? _cleanupOwnerUid;
  String? _cleanupToken;
  Timer? _reconcileRetry;
  int _reconcileRetryAttempt = 0;
  String? _observedUid;
  Future<void> _authenticationQueue = Future<void>.value();

  static const _channel = AndroidNotificationChannel(
    'echomeet',
    'EchoMeet',
    description: 'Surveys, meetings and approvals.',
    importance: Importance.high,
  );

  bool get isRegisteredForCurrentUser {
    final user = _auth.currentUser;
    return user?.emailVerified == true &&
        user!.uid == _registeredUid &&
        _registeredToken != null;
  }

  void observeAuthentication() {
    _authentication ??= _auth.userChanges().listen((user) {
      final previousUid = _observedUid;
      _observedUid = user?.uid;
      _authenticationQueue = _authenticationQueue
          .then((_) => _handleAuthenticationChange(previousUid, user))
          .catchError((Object error) {
            if (kDebugMode) {
              debugPrint('Push auth reconciliation failed: $error');
            }
          });
    });
  }

  Future<void> _handleAuthenticationChange(
    String? previousUid,
    User? observedUser,
  ) async {
    if (previousUid != null && previousUid != observedUser?.uid) {
      try {
        await stop(ownerUid: previousUid);
      } catch (_) {
        if (_auth.currentUser?.uid == observedUser?.uid) {
          try {
            await _auth.signOut();
          } catch (_) {}
        }
        return;
      }
    }

    final current = _auth.currentUser;
    if (current?.uid == observedUser?.uid && current?.emailVerified == true) {
      try {
        final result = await startIfEnabled(expectedUid: current!.uid);
        _recordStartOutcome(result == PushStartResult.registered ? null : result);
      } catch (error) {
        _recordStartOutcome(PushStartResult.unavailable, error);
      }
    }
  }

  static PushStartResult? _lastAutomaticFailure;
  static Object? _lastAutomaticError;

  static PushStartResult? get lastAutomaticFailure => _lastAutomaticFailure;

  static Object? get lastAutomaticError => _lastAutomaticError;

  static void clearLastAutomaticFailure() {
    _lastAutomaticFailure = null;
    _lastAutomaticError = null;
  }

  void _recordStartOutcome(PushStartResult? failure, [Object? error]) {
    _lastAutomaticFailure = failure;
    _lastAutomaticError = failure == null ? null : error;
    if (failure == null) return;
    assert(() {
      debugPrint(
        'EchoMeet: automatic push registration did not complete '
        '($failure${error == null ? '' : ' - $error'})',
      );
      return true;
    }());
  }

  Future<PushStartResult> startIfEnabled({String? expectedUid}) async {
    final user = _auth.currentUser;
    if (user == null ||
        !user.emailVerified ||
        (expectedUid != null && user.uid != expectedUid)) {
      return PushStartResult.disabled;
    }

    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(notificationsPreferenceKey) != true) {
      return PushStartResult.disabled;
    }

    final result = await start(expectedUid: user.uid);
    if (result == PushStartResult.unavailable) {
      if (!await persistDisabledPreference(preferences)) {
        _scheduleReconciliation();
      }
    }
    return result;
  }

  Future<PushStartResult> start({String? expectedUid}) async {
    final user = _auth.currentUser;
    final uid = expectedUid ?? user?.uid;
    if (uid == null || user?.uid != uid || user?.emailVerified != true) {
      return PushStartResult.disabled;
    }

    if (_cleanupPending) {
      final cleanupUid = _cleanupOwnerUid;
      final cleanupToken = _cleanupToken;
      try {
        await _clearRegistration(
          ownerUid: cleanupUid,
          knownToken: cleanupToken,
        );
      } catch (cleanupError) {
        _scheduleCleanupRetry(cleanupUid, cleanupToken);
        throw PushCleanupException(null, cleanupError);
      }
      _requireSameVerifiedUser(uid);
    }

    final pending = _startInFlight;
    if (pending != null) {
      final pendingUid = _startInFlightUid;
      final result = await pending;
      if (pendingUid == uid || isRegisteredForCurrentUser) return result;
    }

    final operation = _start(uid);
    _startInFlight = operation;
    _startInFlightUid = uid;
    return operation.whenComplete(() {
      if (identical(_startInFlight, operation)) {
        _startInFlight = null;
        _startInFlightUid = null;
      }
    });
  }

  Future<PushStartResult> _start(String expectedUid) async {
    String? token;
    try {
      _requireSameVerifiedUser(expectedUid);
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        throw StateError('Push notification permission was not granted.');
      }

      await _initialiseLocal();
      token = await _getToken();
      if (token == null) {
        throw StateError('A push notification token was not available.');
      }

      await _foreground?.cancel();
      _foreground = FirebaseMessaging.onMessage.listen(_show);
      await _opened?.cancel();
      _opened = FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => NotificationNavigation.open(message.data),
      );

      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) {
        NotificationNavigation.open(initialMessage.data);
      }

      await _saveToken(expectedUid, token);
      _requireSameVerifiedUser(expectedUid);

      await _tokenRefresh?.cancel();
      _refreshOwnerUid = expectedUid;
      _tokenRefresh = FirebaseMessaging.instance.onTokenRefresh.listen(
        (newToken) => _queueTokenRefresh(expectedUid, newToken),
      );

      _requireSameVerifiedUser(expectedUid);
      _registeredUid = expectedUid;
      _registeredToken = token;
      _reconcileRetry?.cancel();
      _reconcileRetryAttempt = 0;
      return PushStartResult.registered;
    } catch (startError) {
      try {
        await _clearRegistration(ownerUid: expectedUid, knownToken: token);
      } catch (cleanupError) {
        _scheduleCleanupRetry(expectedUid, token);
        throw PushCleanupException(startError, cleanupError);
      }
      if (kDebugMode) {
        debugPrint('Push registration skipped: $startError');
      }
      return PushStartResult.unavailable;
    }
  }

  void _requireSameVerifiedUser(String expectedUid) {
    final current = _auth.currentUser;
    if (current?.uid != expectedUid || current?.emailVerified != true) {
      throw StateError('The authenticated user changed during push setup.');
    }
  }

  void _queueTokenRefresh(String ownerUid, String token) {
    if (_refreshOwnerUid != ownerUid) return;
    _pendingRefreshToken = token;
    _refreshRetryAttempt = 0;
    unawaited(_attemptTokenRefresh(ownerUid));
  }

  Future<void> _attemptTokenRefresh(String ownerUid) async {
    final pendingWrite = _refreshWrite;
    if (pendingWrite != null) {
      await pendingWrite.catchError((_) {});
    }
    final token = _pendingRefreshToken;
    if (token == null || _refreshOwnerUid != ownerUid) return;

    final operation = _saveRefreshedToken(ownerUid, token);
    _refreshWrite = operation;
    try {
      await operation;
      if (_pendingRefreshToken == token) _pendingRefreshToken = null;
      _refreshRetry?.cancel();
      _refreshRetryAttempt = 0;
      if (_pendingRefreshToken != null && _refreshOwnerUid == ownerUid) {
        unawaited(_attemptTokenRefresh(ownerUid));
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Push token refresh could not be saved: $error');
      }
      _scheduleTokenRefreshRetry(ownerUid);
    } finally {
      if (identical(_refreshWrite, operation)) _refreshWrite = null;
    }
  }

  Future<void> _saveRefreshedToken(String ownerUid, String token) async {
    _requireSameVerifiedUser(ownerUid);
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(notificationsPreferenceKey) != true ||
        _refreshOwnerUid != ownerUid) {
      throw StateError('Push notifications are no longer enabled.');
    }

    await _saveToken(ownerUid, token);
    _requireSameVerifiedUser(ownerUid);
    if (_refreshOwnerUid != ownerUid) {
      throw StateError('Push registration was stopped during token refresh.');
    }

    final previousToken = _registeredToken;
    _registeredUid = ownerUid;
    _registeredToken = token;
    if (previousToken != null && previousToken != token) {
      try {
        await _removeServerToken(ownerUid, previousToken);
      } catch (_) {}
    }
  }

  void _scheduleTokenRefreshRetry(String ownerUid) {
    if (_refreshOwnerUid != ownerUid || _pendingRefreshToken == null) return;
    _refreshRetry?.cancel();
    final seconds = <int>[5, 15, 30, 60, 120, 300];
    final index = _refreshRetryAttempt < seconds.length
        ? _refreshRetryAttempt
        : seconds.length - 1;
    _refreshRetryAttempt += 1;
    _refreshRetry = Timer(Duration(seconds: seconds[index]), () {
      unawaited(_attemptTokenRefresh(ownerUid));
    });
  }

  Future<void> stop({String? ownerUid}) async {
    final pendingStart = _startInFlight;
    if (pendingStart != null) {
      try {
        await pendingStart;
      } catch (_) {}
    }

    final uid = ownerUid ?? _registeredUid ?? _auth.currentUser?.uid;
    final token = _registeredUid == uid ? _registeredToken : null;
    try {
      await _clearRegistration(ownerUid: uid, knownToken: token);
    } catch (cleanupError) {
      _scheduleCleanupRetry(uid, token);
      throw PushCleanupException(null, cleanupError);
    }
  }

  Future<void> _clearRegistration({
    String? ownerUid,
    String? knownToken,
  }) async {
    _refreshOwnerUid = null;
    _pendingRefreshToken = null;
    _refreshRetry?.cancel();
    _refreshRetry = null;

    await _tokenRefresh?.cancel();
    await _foreground?.cancel();
    await _opened?.cancel();
    _tokenRefresh = null;
    _foreground = null;
    _opened = null;

    final pendingRefresh = _refreshWrite;
    if (pendingRefresh != null) {
      try {
        await pendingRefresh;
      } catch (_) {}
    }

    if (!kIsWeb) {
      try {
        await _local.cancelAll();
      } catch (_) {}
    }

    var token = knownToken;
    var tokenLookupSucceeded = token != null;
    if (token == null) {
      try {
        token = await _getToken();
        tokenLookupSucceeded = true;
      } catch (_) {}
    }

    var serverRegistrationRemoved = false;
    if (ownerUid != null && token != null) {
      try {
        await _removeServerToken(ownerUid, token);
        serverRegistrationRemoved = true;
      } catch (_) {}
    }

    var deviceTokenDeleted = false;
    try {
      await FirebaseMessaging.instance.deleteToken();
      deviceTokenDeleted = true;
    } catch (_) {}

    final noTokenExists = tokenLookupSucceeded && token == null;
    if (!noTokenExists && !serverRegistrationRemoved && !deviceTokenDeleted) {
      throw StateError('Push notification registration could not be removed.');
    }

    if (ownerUid == null || _registeredUid == ownerUid) {
      _registeredUid = null;
      _registeredToken = null;
    }
    _confirmCleanup();
  }

  void _scheduleCleanupRetry(String? ownerUid, String? token) {
    _cleanupRetry?.cancel();
    _cleanupPending = true;
    _cleanupOwnerUid = ownerUid;
    _cleanupToken = token;
    final generation = ++_cleanupGeneration;
    final seconds = <int>[5, 15, 30, 60, 120, 300];
    final index = _cleanupRetryAttempt < seconds.length
        ? _cleanupRetryAttempt
        : seconds.length - 1;
    _cleanupRetryAttempt += 1;
    _cleanupRetry = Timer(Duration(seconds: seconds[index]), () async {
      if (!_cleanupPending || generation != _cleanupGeneration) return;
      try {
        await _clearRegistration(ownerUid: ownerUid, knownToken: token);
        await reconcilePersistedPreference();
      } catch (_) {
        if (_cleanupPending && generation == _cleanupGeneration) {
          _scheduleCleanupRetry(ownerUid, token);
        }
      }
    });
  }

  void _confirmCleanup() {
    _cleanupPending = false;
    _cleanupOwnerUid = null;
    _cleanupToken = null;
    _cleanupRetry?.cancel();
    _cleanupRetry = null;
    _cleanupRetryAttempt = 0;
    _cleanupGeneration += 1;
  }

  Future<bool> reconcilePersistedPreference() async {
    final preferences = await SharedPreferences.getInstance();
    final enabled = preferences.getBool(notificationsPreferenceKey) == true;
    try {
      if (!enabled) {
        await stop();
        _reconcileRetry?.cancel();
        _reconcileRetryAttempt = 0;
        return false;
      }

      final result = await startIfEnabled();
      final reconciled =
          result == PushStartResult.registered && isRegisteredForCurrentUser;
      if (reconciled) {
        _reconcileRetry?.cancel();
        _reconcileRetryAttempt = 0;
      } else if (preferences.getBool(notificationsPreferenceKey) == true) {
        _scheduleReconciliation();
      }
      return reconciled;
    } catch (_) {
      _scheduleReconciliation();
      rethrow;
    }
  }

  void _scheduleReconciliation() {
    _reconcileRetry?.cancel();
    final seconds = <int>[5, 15, 30, 60, 120, 300];
    final index = _reconcileRetryAttempt < seconds.length
        ? _reconcileRetryAttempt
        : seconds.length - 1;
    _reconcileRetryAttempt += 1;
    _reconcileRetry = Timer(Duration(seconds: seconds[index]), () async {
      try {
        await reconcilePersistedPreference();
      } catch (_) {}
    });
  }

  static Future<bool> persistDisabledPreference(
    SharedPreferences preferences,
  ) async {
    try {
      await preferences.setBool(notificationsPreferenceKey, false);
    } catch (_) {}
    if (preferences.getBool(notificationsPreferenceKey) != true) return true;
    try {
      await preferences.remove(notificationsPreferenceKey);
    } catch (_) {}
    return preferences.getBool(notificationsPreferenceKey) != true;
  }

  Future<void> _saveToken(String uid, String token) async {
    await _db.collection('users').doc(uid).update({
      'fcmTokens': FieldValue.arrayUnion([token]),
    });
  }

  Future<void> _removeServerToken(String uid, String token) async {
    await _db.collection('users').doc(uid).update({
      'fcmTokens': FieldValue.arrayRemove([token]),
    });
  }

  Future<String?> _getToken() {
    if (kIsWeb && _webVapidKey.isEmpty) {
      throw StateError('Web push requires FCM_WEB_VAPID_KEY.');
    }
    return FirebaseMessaging.instance.getToken(
      vapidKey: kIsWeb ? _webVapidKey : null,
    );
  }

  Future<void> _initialiseLocal() async {
    if (kIsWeb || _localInitialised) return;

    final initialised = await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final data = jsonDecode(payload);
          if (data is Map<String, dynamic>) {
            NotificationNavigation.open(data);
          }
        } on FormatException {
          // ignore: empty_catches
        }
      },
    );
    if (initialised != true) {
      throw StateError('Local notifications could not be initialized.');
    }

    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);
    _localInitialised = true;
  }

  Future<void> _show(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    if (kIsWeb) {
      NotificationNavigation.showForeground(
        title: notification.title,
        body: notification.body,
        data: message.data,
      );
      return;
    }

    await _local.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }
}
