import 'package:echomeet/core/time/device_time_zone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('refreshes the IANA zone when the app resumes', (tester) async {
    var reported = 'Europe/Berlin';
    final controller = DeviceTimeZone(
      loader: () async => reported,
      startAutomatically: false,
    );
    addTearDown(controller.dispose);

    await controller.refresh();
    expect(controller.zoneId, 'Europe/Berlin');

    reported = 'America/New_York';
    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    expect(controller.zoneId, 'America/New_York');
  });

  testWidgets('invalid platform identifiers fail closed', (tester) async {
    final controller = DeviceTimeZone(
      loader: () async => 'not/an-iana-zone',
      startAutomatically: false,
    );
    addTearDown(controller.dispose);

    await controller.refresh();
    expect(controller.zoneId, isNull);
    expect(controller.error, isNotNull);
  });
}
