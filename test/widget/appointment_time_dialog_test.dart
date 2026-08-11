import 'package:echomeet/appointments/widgets/appointment_time_dialogs.dart';
import 'package:echomeet/core/time/appointment_time.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/load_translations.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadAppTranslations();
  });

  testWidgets('repeated wall time requires an explicit occurrence', (
    tester,
  ) async {
    final candidates = resolveAppointmentWallTime(
      zoneId: 'Europe/Berlin',
      wallTime: DateTime.utc(2026, 10, 25, 2, 30),
    ).instants;
    DateTime? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: Column(
              children: [
                FilledButton(
                  onPressed: () async {
                    final value = await chooseRepeatedAppointmentTime(
                      context,
                      candidates,
                      'Europe/Berlin',
                    );
                    setState(() => selected = value);
                  },
                  child: const Text('choose'),
                ),
                Text('${selected?.millisecondsSinceEpoch ?? ''}'),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('choose'));
    await tester.pumpAndSettle();
    expect(find.textContaining('UTC+02:00'), findsOneWidget);
    expect(find.textContaining('UTC+01:00'), findsOneWidget);

    await tester.tap(find.textContaining('Second occurrence'));
    await tester.pumpAndSettle();
    expect(
      find.text('${candidates.last.millisecondsSinceEpoch}'),
      findsOneWidget,
    );
  });

  testWidgets('nonexistent wall time is rejected with corrective copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () => showNonexistentAppointmentTime(context),
            child: const Text('show'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('show'));
    await tester.pumpAndSettle();
    expect(find.text('This time does not exist'), findsOneWidget);
    expect(find.textContaining('daylight saving'), findsOneWidget);
  });
}
