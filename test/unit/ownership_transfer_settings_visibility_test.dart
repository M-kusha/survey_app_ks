import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Settings gates ownership actions to owner and named recipient', () {
    final settings = File('lib/settings/settings.dart').readAsStringSync();

    expect(settings, contains('_isSuperAdmin &&'));
    expect(settings, contains('membership?.isActive == true'));
    expect(settings, contains('membership?.isClosing == false'));
    expect(settings, contains('ownershipOffer?.targetUid == _userId'));
    expect(
      settings,
      contains('onTap: ownershipOfferExpired ? null : _acceptOwnership'),
    );
    expect(settings, contains('OwnershipTransferPage('));
    expect(settings, contains('OwnershipTransferService().accept'));
    expect(settings, isNot(contains("'action': 'request'")));
    expect(settings, isNot(contains("'action': 'accept'")));
  });

  test('Membership keeps the optional offer on its live company stream', () {
    final membership = File(
      'lib/core/membership/membership.dart',
    ).readAsStringSync();

    expect(
      'OwnershipTransferOffer.fromCompanyData'.allMatches(membership),
      hasLength(2),
    );
    expect(membership, contains('ownershipTransfer: _ownershipTransfer'));
  });

  for (final locale in const ['en', 'de', 'sq']) {
    test('ownership transfer has complete safe copy in $locale', () {
      final copy =
          jsonDecode(
                File('assets/translations/$locale.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      for (final key in const {
        'accept_ownership',
        'accept_ownership_confirm',
        'accept_ownership_hint',
        'ownership_transfer_accepted',
        'ownership_transfer_account_deleting',
        'ownership_transfer_account_unavailable',
        'ownership_transfer_company_closing',
        'ownership_transfer_expired',
        'ownership_transfer_no_members',
        'ownership_transfer_not_available',
        'ownership_transfer_owner_required',
        'ownership_transfer_recent_login',
        'ownership_transfer_requested',
        'ownership_transfer_state_invalid',
        'ownership_transfer_target_unavailable',
        'ownership_transfer_unavailable',
        'transfer_ownership',
        'transfer_ownership_confirm',
        'transfer_ownership_hint',
        'transfer_ownership_members',
        'transfer_ownership_warning',
      }) {
        expect(copy[key], isA<String>(), reason: '$locale:$key');
        expect((copy[key] as String).trim(), isNotEmpty);
        expect(copy[key], isNot(key));
      }
    });
  }
}
