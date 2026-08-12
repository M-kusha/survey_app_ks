import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/login/session_access.dart';
import 'package:echomeet/utilities/bottom_navigation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class NotificationNavigation {
  NotificationNavigation._();

  static final navigatorKey = GlobalKey<NavigatorState>();
  static Map<String, dynamic>? _pending;

  static void open(Map<String, dynamic> data) {
    if (_tabFor(data['type']) == null) return;
    _pending = Map<String, dynamic>.from(data);
    appReady();
  }

  static void showForeground({
    required String? title,
    required String? body,
    required Map<String, dynamic> data,
  }) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final parts = [
      if (title?.trim().isNotEmpty == true) title!.trim(),
      if (body?.trim().isNotEmpty == true) body!.trim(),
    ];
    if (parts.isEmpty) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(parts.join('\n')),
        behavior: SnackBarBehavior.floating,
        action: _tabFor(data['type']) == null
            ? null
            : SnackBarAction(label: 'open'.tr(), onPressed: () => open(data)),
      ),
    );
  }

  static void appReady() {
    final data = _pending;
    final context = navigatorKey.currentContext;
    final user = FirebaseAuth.instance.currentUser;
    if (data == null || context == null || user?.emailVerified != true) return;
    if (!context.read<SessionAccess>().isUnlocked) return;

    final tab = _tabFor(data['type']);
    if (tab == null) {
      _pending = null;
      return;
    }

    _pending = null;
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => BottomNavigation(initialIndex: tab),
        settings: RouteSettings(name: '/notification/${data['type']}'),
      ),
      (_) => false,
    );
  }

  static int? _tabFor(Object? type) => switch (type) {
    'survey' => 2,
    'appointment' => 1,
    'approval' => 3,
    'company_closed' => 3,
    _ => null,
  };
}
