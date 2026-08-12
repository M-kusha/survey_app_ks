import 'package:echomeet/appointments/widgets/appointment_time_text.dart';
import 'package:echomeet/core/time/appointment_time.dart';
import 'package:echomeet/core/time/device_time_zone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../support/load_translations.dart';

Future<DeviceTimeZone> _zone(
  WidgetTester tester,
  String Function() reported,
) async {
  final deviceTimeZone = DeviceTimeZone(
    loader: () async => reported(),
    startAutomatically: false,
  );
  addTearDown(deviceTimeZone.dispose);
  await deviceTimeZone.refresh();
  return deviceTimeZone;
}

Future<void> _pump(
  WidgetTester tester,
  DeviceTimeZone deviceTimeZone, {
  required DateTime startAt,
  required DateTime endAt,
  String organizerZone = 'Europe/Berlin',
  bool showOrganizerZone = true,
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<DeviceTimeZone>.value(
      value: deviceTimeZone,
      child: MaterialApp(
        home: Scaffold(
          body: AppointmentTimeText(
            startAt: startAt,
            endAt: endAt,
            zoneId: organizerZone,
            showOrganizerZone: showOrganizerZone,
          ),
        ),
      ),
    ),
  );
}

List<String> _lines(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((text) => text.data)
    .whereType<String>()
    .toList();

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadAppTranslations();
  });

  testWidgets('the reader in the organizer zone sees one unlabelled time', (
    tester,
  ) async {
    final deviceTimeZone = await _zone(tester, () => 'Europe/Berlin');
    await _pump(
      tester,
      deviceTimeZone,
      startAt: DateTime.utc(2026, 8, 10, 9),
      endAt: DateTime.utc(2026, 8, 10, 10),
    );

    final lines = _lines(tester);
    expect(lines, hasLength(1));
    expect(lines.single, contains('11:00'));
    expect(lines.single, isNot(contains('Europe/Berlin')));
  });

  testWidgets('a reader elsewhere sees their own time, then the organizer’s', (
    tester,
  ) async {
    var reported = 'Europe/Berlin';
    final deviceTimeZone = await _zone(tester, () => reported);
    await _pump(
      tester,
      deviceTimeZone,
      startAt: DateTime.utc(2026, 8, 10, 9),
      endAt: DateTime.utc(2026, 8, 10, 10),
    );

    reported = 'America/New_York';
    await deviceTimeZone.refresh();
    await tester.pump();

    final lines = _lines(tester);
    expect(lines, hasLength(2));
    expect(lines.first, contains('5:00'));
    expect(lines.first, isNot(contains('11:00')));

    expect(lines.last, contains('11:00'));
    expect(lines.last, contains('Europe/Berlin'));
  });

  testWidgets('a compact caller can suppress the organizer line', (
    tester,
  ) async {
    final deviceTimeZone = await _zone(tester, () => 'America/New_York');
    await _pump(
      tester,
      deviceTimeZone,
      startAt: DateTime.utc(2026, 8, 10, 9),
      endAt: DateTime.utc(2026, 8, 10, 10),
      showOrganizerZone: false,
    );

    expect(_lines(tester), hasLength(1));
  });

  testWidgets('a meeting across the clock change still warns about it', (
    tester,
  ) async {
    final deviceTimeZone = await _zone(tester, () => 'Europe/Berlin');
    final startAt = resolveAppointmentWallTime(
      zoneId: 'Europe/Berlin',
      wallTime: DateTime.utc(2026, 10, 25, 2, 30),
    ).instants.first;

    await _pump(
      tester,
      deviceTimeZone,
      startAt: startAt,
      endAt: startAt.add(const Duration(hours: 1)),
    );

    expect(_lines(tester).first, contains('UTC+02:00 → UTC+01:00'));
  });

  testWidgets('an ordinary meeting carries no offset clutter', (tester) async {
    final deviceTimeZone = await _zone(tester, () => 'Europe/Berlin');
    await _pump(
      tester,
      deviceTimeZone,
      startAt: DateTime.utc(2026, 8, 10, 9),
      endAt: DateTime.utc(2026, 8, 10, 10),
    );

    expect(_lines(tester).single, isNot(contains('UTC')));
  });
}
