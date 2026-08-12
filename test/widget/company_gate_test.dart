import 'package:echomeet/core/membership/company_gate.dart';
import 'package:echomeet/core/membership/membership.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/load_translations.dart';

Future<void> _pump(WidgetTester tester, Membership? membership) async {
  await tester.pumpWidget(
    MaterialApp(
      home: CompanyGate(membership: membership, onChanged: () async {}),
    ),
  );
  await tester.pumpAndSettle();
}

/// Anything a person can read or press. A gate that renders none of these is
/// the blank page this widget exists to prevent.
int _actionableWidgets(WidgetTester tester) =>
    tester.widgetList<Text>(find.byType(Text)).length;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadAppTranslations();
  });

  testWidgets('a membership that failed to load offers a retry, not a blank', (
    tester,
  ) async {
    // The bug this replaces: `MembershipProvider` leaves the membership null and
    // records an error when the read fails, and the gate returned its child —
    // which both callers set to `SizedBox.shrink()`. A transient Firestore
    // error therefore rendered an empty page with no message and no way back.
    await _pump(tester, null);

    expect(_actionableWidgets(tester), greaterThan(0));
    expect(find.widgetWithText(FilledButton, 'Try again'), findsOneWidget);
    // It must not claim the person has no company: it does not know that.
    expect(find.text('Find a company'), findsNothing);
  });

  testWidgets('every membership state renders something', (tester) async {
    // The states are what the gate switches on, so a new one added without a
    // branch would fall through. Blank must be unreachable for all of them.
    for (final state in MembershipState.values) {
      await _pump(
        tester,
        Membership(state: state, companyId: 'c', companyName: 'Acme'),
      );

      expect(
        _actionableWidgets(tester),
        greaterThan(0),
        reason: '$state renders nothing',
      );
    }
  });

  testWidgets('a pending member is told which company is reviewing them', (
    tester,
  ) async {
    await _pump(
      tester,
      const Membership(
        state: MembershipState.pending,
        companyId: 'c',
        companyName: 'Acme',
      ),
    );

    expect(find.textContaining('Acme'), findsWidgets);
  });

  testWidgets('someone with no company is offered one', (tester) async {
    await _pump(tester, const Membership(state: MembershipState.noCompany));

    expect(find.textContaining('Find a company'), findsOneWidget);
  });
}
