import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

typedef AdministerCompanyCallable =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> payload);

@immutable
class BannedMember {
  const BannedMember({
    required this.userId,
    required this.name,
    required this.previousMembership,
    this.bannedAt,
  });

  final String userId;
  final String name;
  final String previousMembership;
  final DateTime? bannedAt;
}

class CompanyReauthenticationFailure implements Exception {
  const CompanyReauthenticationFailure();
}

@visibleForTesting
Future<void> reauthenticateForCompanyDeletion({
  required String email,
  required String password,
  required Future<void> Function(AuthCredential credential) reauthenticate,
  required Future<void> Function() forceRefresh,
}) async {
  final credential = EmailAuthProvider.credential(
    email: email,
    password: password,
  );
  try {
    await reauthenticate(credential);
  } on FirebaseAuthException {
    throw const CompanyReauthenticationFailure();
  }
  await forceRefresh();
}

class CompanyAdminService {
  CompanyAdminService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
    AdministerCompanyCallable? administerCompanyCallable,
  }) : _providedFirestore = firestore,
       _providedAuth = auth,
       _administerCompany =
           administerCompanyCallable ??
           ((payload) => _firebaseAdministerCompany(functions, payload));

  final FirebaseFirestore? _providedFirestore;
  final FirebaseAuth? _providedAuth;
  final AdministerCompanyCallable _administerCompany;

  FirebaseFirestore get _db => _providedFirestore ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _providedAuth ?? FirebaseAuth.instance;

  static Future<Map<String, dynamic>> _firebaseAdministerCompany(
    FirebaseFunctions? functions,
    Map<String, dynamic> payload,
  ) async {
    final result =
        await (functions ??
                FirebaseFunctions.instanceFor(region: 'europe-west4'))
            .httpsCallable(
              'administerCompany',
              options: HttpsCallableOptions(
                timeout: const Duration(minutes: 2),
              ),
            )
            .call<Map<String, dynamic>>(payload);
    return result.data;
  }

  CollectionReference<Map<String, dynamic>> _bans(String companyId) =>
      _db.collection('companies').doc(companyId).collection('bans');

  Future<void> ban(String userId) async {
    await _targetAction(
      'banMember',
      userId,
      expected: {'membership': 'pending'},
    );
  }

  Future<void> unban(String userId) async {
    await _targetAction('unbanMember', userId);
  }

  Future<List<BannedMember>> bannedMembers(String companyId) async {
    final snapshots = await Future.wait([
      _bans(companyId).get(),
      _db
          .collection('memberDirectory')
          .where('companyId', isEqualTo: companyId)
          .get(),
    ]);
    final bans = snapshots[0];
    final directory = snapshots[1];
    final names = <String, String>{
      for (final member in directory.docs)
        if ((member.data()['fullName'] as String? ?? '').trim().isNotEmpty)
          member.id: (member.data()['fullName'] as String).trim(),
    };

    final members = bans.docs
        .map(
          (doc) => BannedMember(
            userId: doc.id,
            name: names[doc.id] ?? '',
            previousMembership: doc.data()['previousMembership'] == 'pending'
                ? 'pending'
                : 'active',
            bannedAt: (doc.data()['bannedAt'] as Timestamp?)?.toDate(),
          ),
        )
        .toList();

    members.sort((a, b) {
      final aLabel = a.name.isEmpty ? a.userId : a.name;
      final bLabel = b.name.isEmpty ? b.userId : b.name;
      return aLabel.toLowerCase().compareTo(bLabel.toLowerCase());
    });
    return members;
  }

  Future<void> approve(String userId) async {
    await _targetAction(
      'approveMember',
      userId,
      expected: {'membership': 'active'},
    );
  }

  Future<void> changeRole(String userId, String role) async {
    if (!const {'user', 'moderator', 'admin'}.contains(role)) {
      throw ArgumentError.value(role, 'role', 'Unsupported company role.');
    }
    await _targetAction(
      'changeMemberRole',
      userId,
      extra: {'role': role},
      expected: {'role': role},
    );
  }

  Future<void> remove(String userId) async {
    await _targetAction('removeMember', userId, expected: {'released': true});
  }

  Future<void> erase(String userId) async {
    await _targetAction(
      'eraseMemberCompanyData',
      userId,
      expected: {'released': true},
    );
  }

  static const gracePeriod = Duration(days: 7);

  Future<DateTime> scheduleDeletion({required String password}) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw StateError('No signed-in user can schedule company deletion.');
    }
    await reauthenticateForCompanyDeletion(
      email: user.email!,
      password: password,
      reauthenticate: (credential) async {
        await user.reauthenticateWithCredential(credential);
      },
      forceRefresh: () async {
        await user.getIdToken(true);
      },
    );

    final receipt = await _request('scheduleDeletion');
    final millis = receipt['deletionScheduledForMillis'];
    if (millis is! num) {
      throw const FormatException(
        'The company administration response was incomplete.',
      );
    }
    return DateTime.fromMillisecondsSinceEpoch(millis.toInt());
  }

  Future<void> cancelDeletion() async {
    await _request('cancelDeletion', expected: {'cancelled': true});
  }

  Future<int> pendingCount(String companyId) async {
    final snapshot = await _db
        .collection('memberDirectory')
        .where('companyId', isEqualTo: companyId)
        .where('membership', isEqualTo: 'pending')
        .get();

    return snapshot.docs.length;
  }

  Future<void> setJoinPolicy({required bool open}) async {
    final policy = open ? 'open' : 'approval';
    await _request(
      'setJoinPolicy',
      payload: {'joinPolicy': policy},
      expected: {'joinPolicy': policy},
    );
  }

  Future<bool> isOpenToJoin(String companyId) async {
    final company = await _db.collection('companies').doc(companyId).get();
    return (company.data()?['joinPolicy'] as String? ?? 'open') == 'open';
  }

  Future<void> _targetAction(
    String action,
    String targetUid, {
    Map<String, dynamic> extra = const {},
    Map<String, dynamic> expected = const {},
  }) async {
    final receipt = await _request(
      action,
      payload: {'targetUid': targetUid, ...extra},
      expected: expected,
    );
    if (receipt['targetUid'] != targetUid) {
      throw const FormatException(
        'The company administration response was incomplete.',
      );
    }
  }

  Future<Map<String, dynamic>> _request(
    String action, {
    Map<String, dynamic> payload = const {},
    Map<String, dynamic> expected = const {},
  }) async {
    final receipt = await _administerCompany({'action': action, ...payload});
    if (receipt['completed'] != true ||
        receipt['action'] != action ||
        (receipt['companyId'] is! String ||
            (receipt['companyId'] as String).trim().isEmpty) ||
        (receipt['activityId'] is! String ||
            (receipt['activityId'] as String).trim().isEmpty)) {
      throw const FormatException(
        'The company administration response was incomplete.',
      );
    }
    for (final entry in expected.entries) {
      if (receipt[entry.key] != entry.value) {
        throw const FormatException(
          'The company administration response was incomplete.',
        );
      }
    }
    return receipt;
  }
}
