import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

@immutable
class BannedMember {
  const BannedMember({required this.userId, required this.name, this.bannedAt});

  final String userId;
  final String name;
  final DateTime? bannedAt;
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
  }) async {
    await _bans(companyId).doc(userId).set({
      'name': name,
      'bannedAt': FieldValue.serverTimestamp(),
      'bannedBy': _auth.currentUser?.uid,
    });
  }

  Future<void> unban({
    required String companyId,
    required String userId,
  }) async {
    await _bans(companyId).doc(userId).delete();
  }

  Future<List<BannedMember>> bannedMembers(String companyId) async {
    final snapshot = await _bans(companyId).get();

    final members = snapshot.docs
        .map(
          (doc) => BannedMember(
            userId: doc.id,
            name: (doc.data()['name'] as String? ?? '').trim(),
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
    await _db.collection('users').doc(userId).update({'membership': 'active'});
  }

  Future<void> erase({
    required String companyId,
    required String userId,
  }) async {
    final surveys = await _db
        .collection('surveys')
        .where('companyId', isEqualTo: companyId)
        .get();

    for (final survey in surveys.docs) {
      await survey.reference
          .collection('participants')
          .doc(userId)
          .delete()
          .catchError((_) {});
    }

    final appointments = await _db
        .collection('appointments')
        .where('companyId', isEqualTo: companyId)
        .get();

    for (final appointment in appointments.docs) {
      final votes = await appointment.reference
          .collection('participants')
          .where('userId', isEqualTo: userId)
          .get();

      for (final vote in votes.docs) {
        await vote.reference.delete().catchError((_) {});
      }

      await appointment.reference
          .update({
            'participantUserIds': FieldValue.arrayRemove([userId]),
          })
          .catchError((_) {});
    }

    await _db.collection('users').doc(userId).update({
      'companyId': '',
      'role': 'user',
      'membership': 'active',
    });

    await unban(companyId: companyId, userId: userId);
  }

  static const gracePeriod = Duration(days: 7);

  Future<DateTime> scheduleDeletion(String companyId) async {
    final at = DateTime.now().add(gracePeriod);

    await _db.collection('companies').doc(companyId).update({
      'deletionScheduledFor': Timestamp.fromDate(at),
      'deletionRequestedBy': _auth.currentUser?.uid,
    });

    return at;
  }

  Future<void> cancelDeletion(String companyId) async {
    await _db.collection('companies').doc(companyId).update({
      'deletionScheduledFor': FieldValue.delete(),
      'deletionRequestedBy': FieldValue.delete(),
    });
  }

  Future<void> purgeCompany(String companyId) async {
    final me = _auth.currentUser?.uid;

    Future<void> purgeChildren(
      Query<Map<String, dynamic>> parents,
      String childCollection,
    ) async {
      for (final parent in (await parents.get()).docs) {
        final children = await parent.reference
            .collection(childCollection)
            .get();
        for (final chunk in _chunked(children.docs)) {
          final batch = _db.batch();
          for (final child in chunk) {
            batch.delete(child.reference);
          }
          await batch.commit();
        }

        await parent.reference.delete();
      }
    }

    await purgeChildren(
      _db.collection('surveys').where('companyId', isEqualTo: companyId),
      'participants',
    );
    await purgeChildren(
      _db.collection('appointments').where('companyId', isEqualTo: companyId),
      'participants',
    );

    final bans = await _bans(companyId).get();
    for (final ban in bans.docs) {
      await ban.reference.delete().catchError((_) {});
    }

    final members = await _db
        .collection('users')
        .where('companyId', isEqualTo: companyId)
        .get();

    for (final member in members.docs) {
      if (member.id == me) continue;
      await member.reference
          .update({'companyId': '', 'role': 'user', 'membership': 'active'})
          .catchError((_) {});
    }

    final names = await _db
        .collection('companyNames')
        .where('companyId', isEqualTo: companyId)
        .get();
    for (final name in names.docs) {
      await name.reference.delete().catchError((_) {});
    }

    await _db.collection('companies').doc(companyId).delete();

    if (me != null) {
      await _db.collection('users').doc(me).update({
        'companyId': '',
        'role': 'user',
        'membership': 'active',
      });
    }
  }

  static Iterable<List<T>> _chunked<T>(List<T> items, [int size = 400]) sync* {
    for (var start = 0; start < items.length; start += size) {
      yield items.sublist(start, (start + size).clamp(0, items.length));
    }
  }

  Future<int> pendingCount(String companyId) async {
    final snapshot = await _db
        .collection('users')
        .where('companyId', isEqualTo: companyId)
        .where('membership', isEqualTo: 'pending')
        .get();

    return snapshot.docs.length;
  }

  Future<void> setJoinPolicy({
    required String companyId,
    required bool open,
  }) async {
    await _db.collection('companies').doc(companyId).update({
      'joinPolicy': open ? 'open' : 'approval',
    });
  }

  Future<bool> isOpenToJoin(String companyId) async {
    final company = await _db.collection('companies').doc(companyId).get();
    return (company.data()?['joinPolicy'] as String? ?? 'open') == 'open';
  }
}
