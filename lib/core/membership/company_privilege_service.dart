import 'package:cloud_functions/cloud_functions.dart';
import 'package:echomeet/core/security/recent_auth_service.dart';
import 'package:flutter/foundation.dart';

typedef CreateCompanyCallable =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> payload);
typedef RecentPasswordAuthenticator = Future<void> Function(String password);

enum CompanyCreationFailure {
  invalidName,
  nameTaken,
  ineligible,
  recentLoginRequired,
  accountUnavailable,
  invalidCredential,
  unavailable,
}

@immutable
class CompanyCreationException implements Exception {
  const CompanyCreationException(this.failure);

  final CompanyCreationFailure failure;
}

@immutable
class CompanyCreationReceipt {
  const CompanyCreationReceipt({
    required this.companyId,
    required this.activityId,
  });

  final String companyId;
  final String activityId;
}

class CompanyPrivilegeService {
  CompanyPrivilegeService({
    FirebaseFunctions? functions,
    RecentAuthService? recentAuth,
    RecentPasswordAuthenticator? recentPasswordAuthenticator,
    CreateCompanyCallable? createCompanyCallable,
  }) : _authenticate =
           recentPasswordAuthenticator ??
           (recentAuth ?? RecentAuthService()).confirmPassword,
       _createCompany =
           createCompanyCallable ??
           ((payload) => _firebaseCreateCompany(functions, payload));

  static const maxCompanyNameLength = 120;

  final RecentPasswordAuthenticator _authenticate;
  final CreateCompanyCallable _createCompany;

  static bool isValidCompanyName(String value) {
    final name = value.trim();
    return name.isNotEmpty && name.length <= maxCompanyNameLength;
  }

  Future<CompanyCreationReceipt> createCompany({
    required String companyName,
    required String password,
  }) async {
    final name = companyName.trim();
    if (!isValidCompanyName(name)) {
      throw const CompanyCreationException(CompanyCreationFailure.invalidName);
    }

    try {
      await _authenticate(password);
    } on RecentAuthenticationException catch (error) {
      throw CompanyCreationException(switch (error.failure) {
        RecentAuthenticationFailure.invalidCredential =>
          CompanyCreationFailure.invalidCredential,
        RecentAuthenticationFailure.accountUnavailable =>
          CompanyCreationFailure.accountUnavailable,
        RecentAuthenticationFailure.unavailable =>
          CompanyCreationFailure.unavailable,
      });
    } catch (_) {
      throw const CompanyCreationException(CompanyCreationFailure.unavailable);
    }

    final Map<String, dynamic> data;
    try {
      data = await _createCompany({'companyName': name});
    } on FirebaseFunctionsException catch (error) {
      throw CompanyCreationException(_failureFor(error));
    } catch (_) {
      throw const CompanyCreationException(CompanyCreationFailure.unavailable);
    }

    const receiptKeys = {'created', 'companyId', 'role', 'activityId'};
    final companyId = data['companyId'];
    final activityId = data['activityId'];
    if (!setEquals(data.keys.toSet(), receiptKeys) ||
        data['created'] != true ||
        companyId is! String ||
        companyId.trim().isEmpty ||
        data['role'] != 'superadmin' ||
        activityId is! String ||
        activityId.trim().isEmpty) {
      throw const CompanyCreationException(CompanyCreationFailure.unavailable);
    }

    return CompanyCreationReceipt(
      companyId: companyId.trim(),
      activityId: activityId.trim(),
    );
  }

  static Future<Map<String, dynamic>> _firebaseCreateCompany(
    FirebaseFunctions? functions,
    Map<String, dynamic> payload,
  ) async {
    final result =
        await (functions ??
                FirebaseFunctions.instanceFor(region: 'europe-west4'))
            .httpsCallable(
              'createCompanyForCurrentUser',
              options: HttpsCallableOptions(
                timeout: const Duration(seconds: 30),
              ),
            )
            .call<Map<String, dynamic>>(payload);
    return result.data;
  }

  static CompanyCreationFailure _failureFor(FirebaseFunctionsException error) {
    final message = error.message;
    if (error.code == 'already-exists' && message == 'company-name-taken') {
      return CompanyCreationFailure.nameTaken;
    }
    if (error.code == 'invalid-argument' &&
        (message == 'company-name-invalid' ||
            message == 'company-creation-request-invalid')) {
      return CompanyCreationFailure.invalidName;
    }
    if (error.code == 'failed-precondition' &&
        message == 'recent-login-required') {
      return CompanyCreationFailure.recentLoginRequired;
    }
    if ((error.code == 'unauthenticated' &&
            message == 'authentication-required') ||
        (error.code == 'failed-precondition' &&
            (message == 'email-not-verified' ||
                message == 'company-creation-account-unavailable'))) {
      return CompanyCreationFailure.accountUnavailable;
    }
    if (error.code == 'failed-precondition' &&
        const {
          'company-creation-profile-invalid',
          'onboarding-pending',
          'account-deletion-started',
          'company-membership-state-invalid',
        }.contains(message)) {
      return CompanyCreationFailure.ineligible;
    }
    return CompanyCreationFailure.unavailable;
  }
}
