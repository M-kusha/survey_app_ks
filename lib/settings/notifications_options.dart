import 'package:echomeet/settings/font_size_provider.dart';
import 'package:echomeet/utilities/text_style.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
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

    // The preference is only written once the OS has actually granted the
    // permission, so the toggle can never show "on" while notifications are
    // blocked at the system level.
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

  /// Asks the OS for permission to post notifications.
  ///
  /// Uses flutter_local_notifications' own platform implementations rather than
  /// a separate permission package: it already ships the Android 13+
  /// POST_NOTIFICATIONS request and the iOS equivalent, so the extra dependency
  /// bought nothing.
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
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    Color buttonColor = getButtonColor(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(widget.icon, size: fontSize + 15),
              const SizedBox(width: 10),
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Transform.scale(
            scale: 0.7,
            child: CupertinoSwitch(
              activeTrackColor: buttonColor,
              inactiveTrackColor: Colors.grey,
              value: _notificationsEnabled,
              onChanged: (bool newValue) {
                _updateNotificationSetting(newValue).then((_) {
                  // Force rebuild if needed
                  if (!context.mounted) return;
                  setState(() {});
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
