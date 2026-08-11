import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:echomeet/core/membership/ownership_transfer_service.dart';
import 'package:echomeet/core/security/recent_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FunctionError extends FirebaseFunctionsException {
  _FunctionError(String code, String message)
    : super(code: code, message: message);
}

Matcher failsWith(OwnershipTransferFailure failure) => throwsA(
  isA<OwnershipTransferException>().having(
    (error) => error.failure,
    'failure',
    failure,
  ),
);

void main() {
  group('ownership transfer callable', () {
    test('reauthenticates before sending the exact request payload', () async {
      final events = <String>[];
      Map<String, dynamic>? payload;
      final service = OwnershipTransferService(
        recentPasswordAuthenticator: (password) async {
          events.add('auth:$password');
        },
        transferCallable: (request) async {
          events.add('call');
          payload = request;
          return {
            'requested': true,
            'companyId': 'company_1',
            'targetUid': 'member_1',
            'expiresAtMillis': 1786665600000,
          };
        },
      );

      final receipt = await service.request(
        targetUid: '  member_1  ',
        password: 'current password',
      );

      expect(events, ['auth:current password', 'call']);
      expect(payload, {'action': 'request', 'targetUid': 'member_1'});
      expect(payload, isNot(contains('password')));
      expect(payload, isNot(contains('companyId')));
      expect(payload, isNot(contains('role')));
      expect(receipt.companyId, 'company_1');
      expect(receipt.targetUid, 'member_1');
      expect(
        receipt.expiresAt,
        DateTime.fromMillisecondsSinceEpoch(1786665600000, isUtc: true),
      );
    });

    test('reauthenticates before sending the exact accept payload', () async {
      final events = <String>[];
      Map<String, dynamic>? payload;
      final service = OwnershipTransferService(
        recentPasswordAuthenticator: (password) async {
          events.add('auth:$password');
        },
        transferCallable: (request) async {
          events.add('call');
          payload = request;
          return {
            'transferred': true,
            'companyId': 'company_1',
            'formerOwnerUid': 'owner_1',
            'newOwnerUid': 'member_1',
            'activityId': 'activity_1',
          };
        },
      );

      final receipt = await service.accept(password: 'current password');

      expect(events, ['auth:current password', 'call']);
      expect(payload, {'action': 'accept'});
      expect(payload, isNot(contains('password')));
      expect(payload, isNot(contains('uid')));
      expect(payload, isNot(contains('companyId')));
      expect(payload, isNot(contains('role')));
      expect(receipt.companyId, 'company_1');
      expect(receipt.formerOwnerUid, 'owner_1');
      expect(receipt.newOwnerUid, 'member_1');
      expect(receipt.activityId, 'activity_1');
    });

    test('rejects invalid targets before authentication', () async {
      var authenticated = false;
      var called = false;
      final service = OwnershipTransferService(
        recentPasswordAuthenticator: (_) async => authenticated = true,
        transferCallable: (_) async {
          called = true;
          return const {};
        },
      );

      await expectLater(
        service.request(targetUid: 'bad/id', password: 'password'),
        failsWith(OwnershipTransferFailure.invalidTarget),
      );
      expect(authenticated, isFalse);
      expect(called, isFalse);
    });

    test('rejects incomplete, inconsistent, or expanded receipts', () async {
      for (final receipt in <Map<String, dynamic>>[
        {
          'requested': true,
          'companyId': 'company_1',
          'targetUid': 'different_member',
          'expiresAtMillis': 1786665600000,
        },
        {
          'requested': true,
          'companyId': 'company_1',
          'targetUid': 'member_1',
          'expiresAtMillis': 1786665600000,
          'extra': true,
        },
        {
          'requested': true,
          'companyId': 'company_1',
          'targetUid': 'member_1',
          'expiresAtMillis': 1.5,
        },
      ]) {
        final service = OwnershipTransferService(
          recentPasswordAuthenticator: (_) async {},
          transferCallable: (_) async => receipt,
        );
        await expectLater(
          service.request(targetUid: 'member_1', password: 'password'),
          failsWith(OwnershipTransferFailure.unavailable),
        );
      }

      for (final receipt in <Map<String, dynamic>>[
        {
          'transferred': true,
          'companyId': 'company_1',
          'formerOwnerUid': 'owner_1',
          'newOwnerUid': 'owner_1',
          'activityId': 'activity_1',
        },
        {
          'transferred': true,
          'companyId': 'company_1',
          'formerOwnerUid': 'owner_1',
          'newOwnerUid': 'member_1',
          'activityId': 'activity_1',
          'extra': true,
        },
      ]) {
        final service = OwnershipTransferService(
          recentPasswordAuthenticator: (_) async {},
          transferCallable: (_) async => receipt,
        );
        await expectLater(
          service.accept(password: 'password'),
          failsWith(OwnershipTransferFailure.unavailable),
        );
      }
    });

    test('maps recent-auth failures without calling the backend', () async {
      for (final entry in {
        RecentAuthenticationFailure.invalidCredential:
            OwnershipTransferFailure.invalidCredential,
        RecentAuthenticationFailure.accountUnavailable:
            OwnershipTransferFailure.accountUnavailable,
        RecentAuthenticationFailure.unavailable:
            OwnershipTransferFailure.unavailable,
      }.entries) {
        var called = false;
        final service = OwnershipTransferService(
          recentPasswordAuthenticator: (_) async {
            throw RecentAuthenticationException(entry.key);
          },
          transferCallable: (_) async {
            called = true;
            return const {};
          },
        );

        await expectLater(
          service.accept(password: 'password'),
          failsWith(entry.value),
        );
        expect(called, isFalse);
      }
    });

    test(
      'maps every stable backend failure to a safe client failure',
      () async {
        final cases = <FirebaseFunctionsException, OwnershipTransferFailure>{
          _FunctionError(
            'invalid-argument',
            'ownership-transfer-request-invalid',
          ): OwnershipTransferFailure.invalidTarget,
          _FunctionError(
            'invalid-argument',
            'ownership-transfer-target-invalid',
          ): OwnershipTransferFailure.invalidTarget,
          _FunctionError('failed-precondition', 'recent-login-required'):
              OwnershipTransferFailure.recentLoginRequired,
          _FunctionError(
            'failed-precondition',
            'ownership-transfer-account-unavailable',
          ): OwnershipTransferFailure.accountUnavailable,
          _FunctionError(
            'failed-precondition',
            'ownership-transfer-target-account-unavailable',
          ): OwnershipTransferFailure.targetAccountUnavailable,
          _FunctionError(
            'failed-precondition',
            'ownership-transfer-state-invalid',
          ): OwnershipTransferFailure.stateInvalid,
          _FunctionError('failed-precondition', 'account-deletion-started'):
              OwnershipTransferFailure.accountDeleting,
          _FunctionError(
            'failed-precondition',
            'ownership-transfer-target-account-deleting',
          ): OwnershipTransferFailure.accountDeleting,
          _FunctionError('failed-precondition', 'company-closing'):
              OwnershipTransferFailure.companyClosing,
          _FunctionError('permission-denied', 'company-owner-required'):
              OwnershipTransferFailure.ownerRequired,
          _FunctionError(
            'permission-denied',
            'ownership-transfer-target-unavailable',
          ): OwnershipTransferFailure.targetUnavailable,
          _FunctionError(
            'failed-precondition',
            'ownership-transfer-not-requested',
          ): OwnershipTransferFailure.notRequested,
          _FunctionError(
            'permission-denied',
            'ownership-transfer-not-recipient',
          ): OwnershipTransferFailure.notRecipient,
          _FunctionError('failed-precondition', 'ownership-transfer-expired'):
              OwnershipTransferFailure.expired,
          _FunctionError('internal', 'sensitive detail'):
              OwnershipTransferFailure.unavailable,
        };

        for (final entry in cases.entries) {
          final service = OwnershipTransferService(
            recentPasswordAuthenticator: (_) async {},
            transferCallable: (_) async => throw entry.key,
          );
          await expectLater(
            service.accept(password: 'password'),
            failsWith(entry.value),
          );
        }
      },
    );
  });

  group('ownership offer and target models', () {
    test('decodes only the exact bounded offer shape', () {
      final requestedAt = DateTime.utc(2026, 8, 12);
      final expiresAt = requestedAt.add(const Duration(hours: 48));
      final company = <String, dynamic>{
        'ownershipTransfer': {
          'fromUid': 'owner_1',
          'targetUid': 'member_1',
          'requestedAt': Timestamp.fromDate(requestedAt),
          'expiresAt': Timestamp.fromDate(expiresAt),
        },
      };

      final offer = OwnershipTransferOffer.fromCompanyData(company);

      expect(offer, isNotNull);
      expect(offer!.fromUid, 'owner_1');
      expect(offer.targetUid, 'member_1');
      expect(offer.requestedAt, requestedAt);
      expect(offer.expiresAt, expiresAt);
      expect(offer.isExpiredAt(expiresAt), isTrue);
      expect(
        offer.isExpiredAt(expiresAt.subtract(const Duration(milliseconds: 1))),
        isFalse,
      );

      expect(
        OwnershipTransferOffer.fromCompanyData({
          ...company,
          'ownershipTransfer': {
            ...(company['ownershipTransfer'] as Map<String, dynamic>),
            'email': 'forbidden@example.test',
          },
        }),
        isNull,
      );
      expect(
        OwnershipTransferOffer.fromCompanyData({
          'ownershipTransfer': {
            'fromUid': 'same',
            'targetUid': 'same',
            'requestedAt': Timestamp.fromDate(requestedAt),
            'expiresAt': Timestamp.fromDate(expiresAt),
          },
        }),
        isNull,
      );
      expect(
        OwnershipTransferOffer.fromCompanyData({
          'ownershipTransfer': {
            'fromUid': 'owner_1',
            'targetUid': 'member_1',
            'requestedAt': Timestamp.fromDate(expiresAt),
            'expiresAt': Timestamp.fromDate(requestedAt),
          },
        }),
        isNull,
      );
      for (final lifetime in const [Duration(hours: 47), Duration(hours: 49)]) {
        expect(
          OwnershipTransferOffer.fromCompanyData({
            'ownershipTransfer': {
              'fromUid': 'owner_1',
              'targetUid': 'member_1',
              'requestedAt': Timestamp.fromDate(requestedAt),
              'expiresAt': Timestamp.fromDate(requestedAt.add(lifetime)),
            },
          }),
          isNull,
        );
      }
      expect(OwnershipTransferOffer.fromCompanyData(const {}), isNull);
    });

    test('accepts only active same-company non-owner directory targets', () {
      Map<String, dynamic> member({
        String companyId = 'company_1',
        String role = 'admin',
        String membership = 'active',
      }) => {
        'fullName': '  Member One  ',
        'companyId': companyId,
        'role': role,
        'membership': membership,
      };

      final target = OwnershipTransferTarget.fromMemberDirectory(
        uid: 'member_1',
        data: member(),
        companyId: 'company_1',
        currentUid: 'owner_1',
      );
      expect(target, isNotNull);
      expect(target!.uid, 'member_1');
      expect(target.fullName, 'Member One');
      expect(target.role, 'admin');

      for (final invalid in <OwnershipTransferTarget?>[
        OwnershipTransferTarget.fromMemberDirectory(
          uid: 'owner_1',
          data: member(),
          companyId: 'company_1',
          currentUid: 'owner_1',
        ),
        OwnershipTransferTarget.fromMemberDirectory(
          uid: 'member_1',
          data: member(companyId: 'company_2'),
          companyId: 'company_1',
          currentUid: 'owner_1',
        ),
        OwnershipTransferTarget.fromMemberDirectory(
          uid: 'member_1',
          data: member(membership: 'pending'),
          companyId: 'company_1',
          currentUid: 'owner_1',
        ),
        OwnershipTransferTarget.fromMemberDirectory(
          uid: 'member_1',
          data: member(role: 'superadmin'),
          companyId: 'company_1',
          currentUid: 'owner_1',
        ),
      ]) {
        expect(invalid, isNull);
      }

      for (final role in const ['user', 'moderator', 'admin']) {
        expect(
          OwnershipTransferTarget.fromMemberDirectory(
            uid: 'member_$role',
            data: member(role: role),
            companyId: 'company_1',
            currentUid: 'owner_1',
          ),
          isNotNull,
        );
      }
    });
  });
}
