import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:echomeet/core/security/recent_auth_service.dart';
import 'package:flutter/foundation.dart';

typedef OwnershipTransferCallable =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> payload);
typedef OwnershipRecentPasswordAuthenticator =
    Future<void> Function(String password);

enum OwnershipTransferFailure {
  invalidTarget,
  ownerRequired,
  targetUnavailable,
  notRecipient,
  notRequested,
  expired,
  companyClosing,
  accountDeleting,
  accountUnavailable,
  targetAccountUnavailable,
  stateInvalid,
  recentLoginRequired,
  invalidCredential,
  unavailable,
}

@immutable
class OwnershipTransferException implements Exception {
  const OwnershipTransferException(this.failure);

  final OwnershipTransferFailure failure;
}

@immutable
class OwnershipTransferRequestReceipt {
  const OwnershipTransferRequestReceipt({
    required this.companyId,
    required this.targetUid,
    required this.expiresAt,
  });

  final String companyId;
  final String targetUid;
  final DateTime expiresAt;
}

@immutable
class OwnershipTransferAcceptanceReceipt {
  const OwnershipTransferAcceptanceReceipt({
    required this.companyId,
    required this.formerOwnerUid,
    required this.newOwnerUid,
    required this.activityId,
  });

  final String companyId;
  final String formerOwnerUid;
  final String newOwnerUid;
  final String activityId;
}

/// The short-lived offer stored on the company document.
///
/// Invalid or expanded values decode to `null`, so an untrusted client cannot
/// turn malformed company state into an actionable acceptance prompt.
@immutable
class OwnershipTransferOffer {
  const OwnershipTransferOffer({
    required this.fromUid,
    required this.targetUid,
    required this.requestedAt,
    required this.expiresAt,
  });

  final String fromUid;
  final String targetUid;
  final DateTime requestedAt;
  final DateTime expiresAt;

  bool isExpiredAt(DateTime now) => !expiresAt.isAfter(now);

  static OwnershipTransferOffer? fromCompanyData(Map<String, dynamic> company) {
    final value = company['ownershipTransfer'];
    if (value == null) return null;
    if (value is! Map ||
        value.length != 4 ||
        value.keys.any(
          (key) =>
              key is! String ||
              !const {
                'fromUid',
                'targetUid',
                'requestedAt',
                'expiresAt',
              }.contains(key),
        )) {
      return null;
    }

    final fromUid = _validId(value['fromUid']);
    final targetUid = _validId(value['targetUid']);
    final requestedAtValue = value['requestedAt'];
    final expiresAtValue = value['expiresAt'];
    if (fromUid == null ||
        targetUid == null ||
        fromUid == targetUid ||
        requestedAtValue is! Timestamp ||
        expiresAtValue is! Timestamp) {
      return null;
    }

    final requestedAt = requestedAtValue.toDate().toUtc();
    final expiresAt = expiresAtValue.toDate().toUtc();
    if (expiresAt.difference(requestedAt) != const Duration(hours: 48)) {
      return null;
    }

    return OwnershipTransferOffer(
      fromUid: fromUid,
      targetUid: targetUid,
      requestedAt: requestedAt,
      expiresAt: expiresAt,
    );
  }
}

/// A directory member that the owner may select as the next owner.
@immutable
class OwnershipTransferTarget {
  const OwnershipTransferTarget({
    required this.uid,
    required this.fullName,
    required this.role,
  });

  final String uid;
  final String fullName;
  final String role;

  static OwnershipTransferTarget? fromMemberDirectory({
    required String uid,
    required Map<String, dynamic> data,
    required String companyId,
    required String currentUid,
  }) {
    final safeUid = _validId(uid);
    final safeCompanyId = _validId(companyId);
    final safeCurrentUid = _validId(currentUid);
    final memberCompanyId = _validId(data['companyId']);
    final nameValue = data['fullName'];
    final roleValue = data['role'];
    if (safeUid == null ||
        safeCompanyId == null ||
        safeCurrentUid == null ||
        safeUid == safeCurrentUid ||
        memberCompanyId != safeCompanyId ||
        data['membership'] != 'active' ||
        nameValue is! String ||
        nameValue.trim().isEmpty ||
        roleValue is! String ||
        !const {'user', 'moderator', 'admin'}.contains(roleValue)) {
      return null;
    }

    return OwnershipTransferTarget(
      uid: safeUid,
      fullName: nameValue.trim(),
      role: roleValue,
    );
  }
}

class OwnershipTransferService {
  OwnershipTransferService({
    FirebaseFunctions? functions,
    RecentAuthService? recentAuth,
    OwnershipRecentPasswordAuthenticator? recentPasswordAuthenticator,
    OwnershipTransferCallable? transferCallable,
  }) : _authenticate =
           recentPasswordAuthenticator ??
           (recentAuth ?? RecentAuthService()).confirmPassword,
       _transfer =
           transferCallable ??
           ((payload) => _firebaseTransfer(functions, payload));

  final OwnershipRecentPasswordAuthenticator _authenticate;
  final OwnershipTransferCallable _transfer;

  Future<OwnershipTransferRequestReceipt> request({
    required String targetUid,
    required String password,
  }) async {
    final target = _validId(targetUid);
    if (target == null) {
      throw const OwnershipTransferException(
        OwnershipTransferFailure.invalidTarget,
      );
    }

    await _confirmPassword(password);

    final data = await _call({'action': 'request', 'targetUid': target});
    const keys = {'requested', 'companyId', 'targetUid', 'expiresAtMillis'};
    final companyId = _validId(data['companyId']);
    final returnedTarget = _validId(data['targetUid']);
    final expiresAtMillis = _wholePositiveMillis(data['expiresAtMillis']);
    if (!setEquals(data.keys.toSet(), keys) ||
        data['requested'] != true ||
        companyId == null ||
        returnedTarget == null ||
        returnedTarget != target ||
        expiresAtMillis == null) {
      throw const OwnershipTransferException(
        OwnershipTransferFailure.unavailable,
      );
    }

    return OwnershipTransferRequestReceipt(
      companyId: companyId,
      targetUid: returnedTarget,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(
        expiresAtMillis,
        isUtc: true,
      ),
    );
  }

  Future<OwnershipTransferAcceptanceReceipt> accept({
    required String password,
  }) async {
    await _confirmPassword(password);

    final data = await _call({'action': 'accept'});
    const keys = {
      'transferred',
      'companyId',
      'formerOwnerUid',
      'newOwnerUid',
      'activityId',
    };
    final companyId = _validId(data['companyId']);
    final formerOwnerUid = _validId(data['formerOwnerUid']);
    final newOwnerUid = _validId(data['newOwnerUid']);
    final activityId = _validId(data['activityId']);
    if (!setEquals(data.keys.toSet(), keys) ||
        data['transferred'] != true ||
        companyId == null ||
        formerOwnerUid == null ||
        newOwnerUid == null ||
        formerOwnerUid == newOwnerUid ||
        activityId == null) {
      throw const OwnershipTransferException(
        OwnershipTransferFailure.unavailable,
      );
    }

    return OwnershipTransferAcceptanceReceipt(
      companyId: companyId,
      formerOwnerUid: formerOwnerUid,
      newOwnerUid: newOwnerUid,
      activityId: activityId,
    );
  }

  Future<void> _confirmPassword(String password) async {
    try {
      await _authenticate(password);
    } on RecentAuthenticationException catch (error) {
      throw OwnershipTransferException(switch (error.failure) {
        RecentAuthenticationFailure.invalidCredential =>
          OwnershipTransferFailure.invalidCredential,
        RecentAuthenticationFailure.accountUnavailable =>
          OwnershipTransferFailure.accountUnavailable,
        RecentAuthenticationFailure.unavailable =>
          OwnershipTransferFailure.unavailable,
      });
    } catch (_) {
      throw const OwnershipTransferException(
        OwnershipTransferFailure.unavailable,
      );
    }
  }

  Future<Map<String, dynamic>> _call(Map<String, dynamic> payload) async {
    try {
      return await _transfer(payload);
    } on FirebaseFunctionsException catch (error) {
      throw OwnershipTransferException(_failureFor(error));
    } catch (_) {
      throw const OwnershipTransferException(
        OwnershipTransferFailure.unavailable,
      );
    }
  }

  static Future<Map<String, dynamic>> _firebaseTransfer(
    FirebaseFunctions? functions,
    Map<String, dynamic> payload,
  ) async {
    final result =
        await (functions ??
                FirebaseFunctions.instanceFor(region: 'europe-west4'))
            .httpsCallable(
              'transferCompanyOwnership',
              options: HttpsCallableOptions(
                timeout: const Duration(seconds: 30),
              ),
            )
            .call<Map<String, dynamic>>(payload);
    return result.data;
  }

  static OwnershipTransferFailure _failureFor(
    FirebaseFunctionsException error,
  ) {
    final key = '${error.code}/${error.message}';
    return switch (key) {
      'invalid-argument/ownership-transfer-request-invalid' ||
      'invalid-argument/ownership-transfer-target-invalid' =>
        OwnershipTransferFailure.invalidTarget,
      'failed-precondition/recent-login-required' =>
        OwnershipTransferFailure.recentLoginRequired,
      'failed-precondition/ownership-transfer-account-unavailable' ||
      'failed-precondition/email-not-verified' ||
      'unauthenticated/authentication-required' =>
        OwnershipTransferFailure.accountUnavailable,
      'failed-precondition/ownership-transfer-target-account-unavailable' =>
        OwnershipTransferFailure.targetAccountUnavailable,
      'failed-precondition/ownership-transfer-state-invalid' =>
        OwnershipTransferFailure.stateInvalid,
      'failed-precondition/account-deletion-started' ||
      'failed-precondition/ownership-transfer-target-account-deleting' =>
        OwnershipTransferFailure.accountDeleting,
      'failed-precondition/company-closing' =>
        OwnershipTransferFailure.companyClosing,
      'permission-denied/company-owner-required' =>
        OwnershipTransferFailure.ownerRequired,
      'permission-denied/ownership-transfer-target-unavailable' =>
        OwnershipTransferFailure.targetUnavailable,
      'failed-precondition/ownership-transfer-not-requested' =>
        OwnershipTransferFailure.notRequested,
      'permission-denied/ownership-transfer-not-recipient' =>
        OwnershipTransferFailure.notRecipient,
      'failed-precondition/ownership-transfer-expired' =>
        OwnershipTransferFailure.expired,
      _ => OwnershipTransferFailure.unavailable,
    };
  }
}

String? _validId(Object? value) {
  if (value is! String) return null;
  final id = value.trim();
  return id.isNotEmpty && id.length <= 128 && !id.contains('/') ? id : null;
}

int? _wholePositiveMillis(Object? value) {
  if (value is! num ||
      !value.isFinite ||
      value <= 0 ||
      value > 8640000000000000 ||
      value != value.roundToDouble()) {
    return null;
  }
  return value.toInt();
}
