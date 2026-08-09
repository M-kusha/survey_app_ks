import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/settings/settings_kit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationsOptions extends StatefulWidget {
  final IconData icon;
  final String title;

  const NotificationsOptions({
    super.key,
    required this.icon,
    required this.title,
  });

  @override
  State<NotificationsOptions> createState() => _NotificationsOptionsState();
}

class _NotificationsOptionsState extends State<NotificationsOptions> {
  bool _notificationsEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadNotificationSetting();
  }

  Future<void> _loadNotificationSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? false;
    });
  }

  final _notifications = FlutterLocalNotificationsPlugin();

  Future<void> _updateNotificationSetting(bool value) async {
    final prefs = await SharedPreferences.getInstance();

    if (!value) {
      await _notifications.cancelAll();
      await prefs.setBool('notificationsEnabled', false);
      if (mounted) setState(() => _notificationsEnabled = false);
      return;
    }

    await _initialiseNotifications();
    final granted = await _requestPermission();

    await prefs.setBool('notificationsEnabled', granted);
    if (mounted) setState(() => _notificationsEnabled = granted);
  }

  Future<void> _initialiseNotifications() => _notifications.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    ),
  );

  Future<bool> _requestPermission() async {
    if (kIsWeb) return true;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final android = _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        return await android?.requestNotificationsPermission() ?? false;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        final darwin = _notifications
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        return await darwin?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSwitchTile(
      icon: widget.icon,
      title: widget.title,

      subtitle: _notificationsEnabled ? null : 'notifications_hint'.tr(),
      value: _notificationsEnabled,
      onChanged: _updateNotificationSetting,
    );
  }
}
