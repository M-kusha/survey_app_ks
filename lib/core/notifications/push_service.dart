import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class PushService {
  PushService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  final _local = FlutterLocalNotificationsPlugin();

  StreamSubscription<String>? _tokenRefresh;
  StreamSubscription<RemoteMessage>? _foreground;

  static const _channel = AndroidNotificationChannel(
    'echomeet',
    'EchoMeet',
    description: 'Surveys, meetings and approvals.',
    importance: Importance.high,
  );

  Future<void> start() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final settings = await FirebaseMessaging.instance.requestPermission();

      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      await _initialiseLocal();

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _saveToken(user.uid, token);

      await _tokenRefresh?.cancel();

      _tokenRefresh = FirebaseMessaging.instance.onTokenRefresh.listen(
        (token) => _saveToken(user.uid, token),
      );

      await _foreground?.cancel();
      _foreground = FirebaseMessaging.onMessage.listen(_show);
    } catch (error) {
      debugPrint('Push registration skipped: $error');
    }
  }

  Future<void> stop() async {
    final user = _auth.currentUser;

    await _tokenRefresh?.cancel();
    await _foreground?.cancel();
    _tokenRefresh = null;
    _foreground = null;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (user != null && token != null) {
        await _db.collection('users').doc(user.uid).update({
          'fcmTokens': FieldValue.arrayRemove([token]),
        });
      }
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }

  Future<void> _saveToken(String uid, String token) async {
    await _db
        .collection('users')
        .doc(uid)
        .update({
          'fcmTokens': FieldValue.arrayUnion([token]),
        })
        .catchError((_) {});
  }

  Future<void> _initialiseLocal() async {
    if (kIsWeb) return;

    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);
  }

  Future<void> _show(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null || kIsWeb) return;

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
    );
  }
}
