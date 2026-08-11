import 'package:echomeet/appointments/widgets/appointment_time_text.dart';
import 'package:echomeet/core/time/appointment_time.dart';
import 'package:echomeet/core/time/device_time_zone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../support/load_translations.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadAppTranslations();
  });

  testWidgets('viewer time refreshes when the reported IANA zone changes', (
    tester,
  ) async {
    var reportedZone = 'Europe/Berlin';
    final deviceTimeZone = DeviceTimeZone(
      loader: () async => reportedZone,
      startAutomatically: false,
    );
    addTearDown(deviceTimeZone.dispose);
    await deviceTimeZone.refresh();

    await tester.pumpWidget(
      ChangeNotifierProvider<DeviceTimeZone>.value(
        value: deviceTimeZone,
        child: MaterialApp(
          home: Scaffold(
            body: AppointmentTimeText(
              startAt: DateTime.utc(2026, 8, 10, 9),
              endAt: DateTime.utc(2026, 8, 10, 10),
              zoneId: 'Europe/Berlin',
            ),
          ),
        ),
      ),
    );

    expect(_lineStartingWith(tester, 'Your time:'), contains('11:00'));
    expect(
      _lineStartingWith(tester, 'Your time:'),
      contains('(Europe/Berlin, UTC+02:00)'),
    );

    reportedZone = 'America/New_York';
    await deviceTimeZone.refresh();
    await tester.pump();

    expect(_lineStartingWith(tester, 'Your time:'), contains('5:00'));
    expect(
      _lineStartingWith(tester, 'Your time:'),
      contains('(America/New_York, UTC-04:00)'),
    );
    expect(_lineStartingWith(tester, 'Organizer time:'), contains('11:00'));
  });

  testWidgets('fall-back crossing labels both endpoint offsets', (
    tester,
  ) async {
    final deviceTimeZone = DeviceTimeZone(
      loader: () async => 'Europe/Berlin',
      startAutomatically: false,
    );
    addTearDown(deviceTimeZone.dispose);
    await deviceTimeZone.refresh();
    final startAt = resolveAppointmentWallTime(
      zoneId: 'Europe/Berlin',
      wallTime: DateTime.utc(2026, 10, 25, 2, 30),
    ).instants.first;

    await tester.pumpWidget(
      ChangeNotifierProvider<DeviceTimeZone>.value(
        value: deviceTimeZone,
        child: MaterialApp(
          home: Scaffold(
            body: AppointmentTimeText(
              startAt: startAt,
              endAt: startAt.add(const Duration(hours: 1)),
              zoneId: 'Europe/Berlin',
            ),
          ),
        ),
      ),
    );

    expect(
      _lineStartingWith(tester, 'Your time:'),
      contains('UTC+02:00 → UTC+01:00'),
    );
    expect(
      _lineStartingWith(tester, 'Organizer time:'),
      contains('UTC+02:00 → UTC+01:00'),
    );
  });
}

String _lineStartingWith(WidgetTester tester, String prefix) => tester
    .widgetList<Text>(find.byType(Text))
    .map((text) => text.data)
    .whereType<String>()
    .singleWhere((text) => text.startsWith(prefix));
