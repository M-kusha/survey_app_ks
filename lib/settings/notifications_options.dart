import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/notifications/push_service.dart';
import 'package:echomeet/settings/settings_kit.dart';
import 'package:flutter/material.dart';
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
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _loadNotificationSetting();
  }

  Future<void> _loadNotificationSetting() async {
    try {
      final enabled = await PushService().reconcilePersistedPreference();
      if (mounted) setState(() => _notificationsEnabled = enabled);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      final registered = PushService().isRegisteredForCurrentUser;
      if (mounted) {
        setState(() {
          _notificationsEnabled =
              prefs.getBool(PushService.notificationsPreferenceKey) == true &&
              registered;
        });
      }
    }
  }

  Future<void> _updateNotificationSetting(bool value) async {
    if (_updating) return;
    setState(() => _updating = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final pushService = PushService();
      if (!value) {
        await pushService.stop();
        if (!await PushService.persistDisabledPreference(prefs)) {
          final reconciled = await pushService.reconcilePersistedPreference();
          if (mounted) setState(() => _notificationsEnabled = reconciled);
          throw StateError('Notification preference could not be saved.');
        }
        if (mounted) setState(() => _notificationsEnabled = false);
        return;
      }

      if (!await prefs.setBool(PushService.notificationsPreferenceKey, true) ||
          prefs.getBool(PushService.notificationsPreferenceKey) != true) {
        throw StateError('Notification preference could not be saved.');
      }
      final result = await pushService.start();
      final registered =
          result == PushStartResult.registered &&
          pushService.isRegisteredForCurrentUser;
      if (!registered) {
        if (result == PushStartResult.unavailable) {
          if (!await PushService.persistDisabledPreference(prefs)) {
            unawaited(pushService.reconcilePersistedPreference());
            throw StateError('Notification preference could not be saved.');
          }
        }
        throw StateError('Push notifications could not be enabled.');
      }
      if (mounted) setState(() => _notificationsEnabled = true);
    } catch (_) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final registered = PushService().isRegisteredForCurrentUser;
        if (mounted) {
          setState(() {
            _notificationsEnabled =
                prefs.getBool(PushService.notificationsPreferenceKey) == true &&
                registered;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _notificationsEnabled = false);
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('error_occurred'.tr())));
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSwitchTile(
      icon: widget.icon,
      title: widget.title,

      subtitle: _notificationsEnabled ? null : 'notifications_hint'.tr(),
      value: _notificationsEnabled,
      onChanged: _updating ? null : _updateNotificationSetting,
    );
  }
}
