import 'dart:async';

import 'package:echomeet/core/time/appointment_time.dart';
import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

typedef DeviceTimeZoneLoader = Future<String> Function();

class DeviceTimeZone extends ChangeNotifier with WidgetsBindingObserver {
  DeviceTimeZone({
    DeviceTimeZoneLoader? loader,
    Duration pollInterval = const Duration(minutes: 1),
    bool startAutomatically = true,
  }) : _loader = loader ?? _loadPlatformTimeZone {
    WidgetsBinding.instance.addObserver(this);
    if (startAutomatically) {
      _poller = Timer.periodic(pollInterval, (_) => unawaited(refresh()));
      unawaited(refresh());
    }
  }

  final DeviceTimeZoneLoader _loader;
  Timer? _poller;
  String? _zoneId;
  Object? _error;
  bool _refreshing = false;
  bool _disposed = false;

  String? get zoneId => _zoneId;
  Object? get error => _error;
  bool get isReady => _zoneId != null;

  Future<void> refresh() async {
    if (_refreshing || _disposed) return;
    _refreshing = true;
    try {
      final next = requireIanaTimeZone(await _loader());
      final changed = next != _zoneId || _error != null;
      _zoneId = next;
      _error = null;
      if (changed && !_disposed) notifyListeners();
    } catch (error) {
      final changed = _error?.toString() != error.toString();
      _error = error;
      if (changed && !_disposed) notifyListeners();
    } finally {
      _refreshing = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _poller?.cancel();
    super.dispose();
  }

  static Future<String> _loadPlatformTimeZone() async =>
      (await FlutterTimezone.getLocalTimezone()).identifier;
}
