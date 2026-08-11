import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:echomeet/appointments/appointment_data.dart';
import 'package:echomeet/core/membership/member_directory.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

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
  CompanyAdminService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> _bans(String companyId) =>
      _db.collection('companies').doc(companyId).collection('bans');

  Future<void> ban({
    required String companyId,
    required String userId,
    required String name,
    required String previousMembership,
  }) async {
    final previous = previousMembership == 'pending' ? 'pending' : 'active';
    final batch = _db.batch();
    batch.set(_bans(companyId).doc(userId), {
      'name': name,
      'bannedAt': FieldValue.serverTimestamp(),
      'bannedBy': _auth.currentUser?.uid,
      'previousMembership': previous,
    });
    // Storage Rules have a hard two-Firestore-read ceiling. Mirroring the
    // revocation into the existing member projection lets those rules verify
    // both people and reject banned viewers without a third ban-document read.
    batch.update(_db.collection('users').doc(userId), {
      'membership': 'pending',
    });
    batch.update(MemberDirectory.reference(_db, userId), {
      'membership': 'pending',
    });
    await batch.commit();
  }

  Future<void> unban({
    required String companyId,
    required String userId,
  }) async {
    final ban = _bans(companyId).doc(userId);
    final member = MemberDirectory.reference(_db, userId);

    await _db.runTransaction((transaction) async {
      final snapshots = await Future.wait([
        transaction.get(ban),
        transaction.get(member),
      ]);
      final banSnapshot = snapshots[0];
      if (!banSnapshot.exists) return;

      final previous = banSnapshot.data()?['previousMembership'] == 'pending'
          ? 'pending'
          : 'active';
      transaction.delete(ban);

      final memberSnapshot = snapshots[1];
      if (!memberSnapshot.exists ||
          memberSnapshot.data()?['companyId'] != companyId) {
        return;
      }
      transaction.update(_db.collection('users').doc(userId), {
        'membership': previous,
      });
      transaction.update(member, {'membership': previous});
    });
  }

  Future<List<BannedMember>> bannedMembers(String companyId) async {
    final snapshot = await _bans(companyId).get();

    final members = snapshot.docs
        .map(
          (doc) => BannedMember(
            userId: doc.id,
            name: (doc.data()['name'] as String? ?? '').trim(),
            previousMembership: doc.data()['previousMembership'] == 'pending'
                ? 'pending'
                : 'active',
            bannedAt: (doc.data()['bannedAt'] as Timestamp?)?.toDate(),
          ),
        )
        .toList();

    members.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return members;
  }

  Future<void> approve(String userId) async {
    await MemberDirectory.updateMember(
      firestore: _db,
      userId: userId,
      fields: {'membership': 'active'},
    );
  }

  Future<void> erase({
    required String companyId,
    required String userId,
  }) async {
    final participantReferences = <DocumentReference<Map<String, dynamic>>>[];
    final surveys = await _db
        .collection('surveys')
        .where('companyId', isEqualTo: companyId)
        .get();

    for (final survey in surveys.docs) {
      participantReferences.add(
        survey.reference.collection('participants').doc(userId),
      );
    }

    final appointments = await _db
        .collection('appointments')
        .where('companyId', isEqualTo: companyId)
        .where('schemaVersion', isEqualTo: Appointment.schemaVersion)
        .get();

    for (final appointment in appointments.docs) {
      final votes = await appointment.reference
          .collection('participants')
          .where('userId', isEqualTo: userId)
          .get();

      for (final vote in votes.docs) {
        participantReferences.add(vote.reference);
      }

      // Trusted vote-delete triggers remove the uid from participantUserIds
      // after the member's final child vote has gone.
    }

    // Resolve every query before mutating anything, then let any failed delete
    // abort the operation. The caller must never report a successful erasure
    // while participant data is still present.
    await _deleteDocuments(participantReferences);

    // Release the profile, remove its public projection and discard any ban in
    // one final write. Separate remove/unban calls can strand an orphan ban on
    // a transient failure, or briefly restore access before removal finishes.
    final release = _db.batch();
    release.update(_db.collection('users').doc(userId), {
      'companyId': '',
      'role': 'user',
      'membership': 'active',
    });
    release.delete(MemberDirectory.reference(_db, userId));
    release.delete(_bans(companyId).doc(userId));
    await release.commit();
  }

  Future<void> _deleteDocuments(
    List<DocumentReference<Map<String, dynamic>>> references,
  ) async {
    // Keep these as individual requests. Participant delete rules perform
    // document lookups, whose per-request ceiling is lower for batched writes.
    for (final reference in references) {
      await reference.delete();
    }
  }

  static const gracePeriod = Duration(days: 7);

  Future<DateTime> scheduleDeletion({
    required String companyId,
    required String password,
  }) async {
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

    final at = DateTime.now().add(gracePeriod);

    await _db.collection('companies').doc(companyId).update({
      'deletionScheduledFor': Timestamp.fromDate(at),
      'deletionRequestedBy': user.uid,
    });

    return at;
  }

  Future<void> cancelDeletion(String companyId) async {
    await _db.collection('companies').doc(companyId).update({
      'deletionScheduledFor': FieldValue.delete(),
      'deletionRequestedBy': FieldValue.delete(),
    });
  }

  Future<int> pendingCount(String companyId) async {
    final snapshot = await _db
        .collection('memberDirectory')
        .where('companyId', isEqualTo: companyId)
        .where('membership', isEqualTo: 'pending')
        .get();

    return snapshot.docs.length;
  }

  Future<void> setJoinPolicy({
    required String companyId,
    required bool open,
  }) async {
    final policy = open ? 'open' : 'approval';
    final batch = _db.batch();
    batch.update(_db.collection('companies').doc(companyId), {
      'joinPolicy': policy,
    });
    batch.update(_db.collection('companyDirectory').doc(companyId), {
      'joinPolicy': policy,
    });
    await batch.commit();
  }

  Future<bool> isOpenToJoin(String companyId) async {
    final company = await _db.collection('companies').doc(companyId).get();
    return (company.data()?['joinPolicy'] as String? ?? 'open') == 'open';
  }
}
