import 'package:echomeet/settings/font_size_provider.dart';
import 'package:echomeet/utilities/text_style.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
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

  Future<void> _updateNotificationSetting(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notificationsEnabled', value);
    if (value) {
      final permission = await Permission.notification.request();
      if (permission.isGranted) {
        _enableNotifications();
      } else {
        setState(() {
          _notificationsEnabled = false;
        });
        await prefs.setBool('notificationsEnabled', false);
      }
    } else {
      _disableNotifications();
    }
  }

  void _enableNotifications() {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    flutterLocalNotificationsPlugin.initialize(initializationSettings);

    setState(() {
      _notificationsEnabled = true;
    });
  }

  void _disableNotifications() {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();
    flutterLocalNotificationsPlugin.cancelAll();

    setState(() {
      _notificationsEnabled = false;
    });
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
              const SizedBox(
                width: 10,
              ),
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
              activeColor: buttonColor,
              trackColor: Colors.grey,
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
