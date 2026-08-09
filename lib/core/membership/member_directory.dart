import 'package:cloud_firestore/cloud_firestore.dart';

/// The company-visible projection of a private `users/{uid}` document.
///
/// Email, birth date, notification tokens and other account data must never be
/// copied here. Security rules make this collection readable to active members
/// of the same company, while the full user document is owner-only.
class MemberDirectory {
  const MemberDirectory._();

  static DocumentReference<Map<String, dynamic>> reference(
    FirebaseFirestore firestore,
    String userId,
  ) => firestore.collection('memberDirectory').doc(userId);

  static Map<String, dynamic> projection(Map<String, dynamic> profile) {
    final result = <String, dynamic>{
      'fullName': profile['fullName'],
      'companyId': profile['companyId'],
      'role': profile['role'],
      'membership': profile['membership'] ?? 'active',
    };
    if (profile['profileImage'] case final String profileImage) {
      result['profileImage'] = profileImage;
    }
    if (profile['profileImageRevision'] case final int revision) {
      result['profileImageRevision'] = revision;
    }
    return result;
  }

  static void setFromProfile(
    WriteBatch batch,
    FirebaseFirestore firestore,
    String userId,
    Map<String, dynamic> profile,
  ) {
    final companyId = (profile['companyId'] as String? ?? '').trim();
    if (companyId.isEmpty) return;
    batch.set(reference(firestore, userId), projection(profile));
  }

  /// Atomically changes the signed-in user's private profile and its public
  /// company projection. Joining creates the projection; leaving removes it.
  static Future<void> updateOwnProfile({
    required FirebaseFirestore firestore,
    required String userId,
    required Map<String, dynamic> fields,
  }) async {
    final user = firestore.collection('users').doc(userId);
    final snapshot = await user.get();
    final current = snapshot.data();
    if (current == null) throw StateError('User profile not found.');

    final next = <String, dynamic>{...current, ...fields};
    final companyId = (next['companyId'] as String? ?? '').trim();
    final batch = firestore.batch();
    batch.update(user, fields);
    if (companyId.isEmpty) {
      batch.delete(reference(firestore, userId));
    } else {
      batch.set(reference(firestore, userId), projection(next));
    }
    await batch.commit();
  }

  /// Atomically changes role or membership fields for an existing colleague.
  /// The caller does not need read access to the private profile document.
  static Future<void> updateMember({
    required FirebaseFirestore firestore,
    required String userId,
    required Map<String, dynamic> fields,
  }) async {
    final batch = firestore.batch();
    batch.update(firestore.collection('users').doc(userId), fields);
    batch.update(reference(firestore, userId), fields);
    await batch.commit();
  }

  /// Releases a member without exposing or reading their private profile.
  static Future<void> removeMember({
    required FirebaseFirestore firestore,
    required String userId,
  }) async {
    final batch = firestore.batch();
    batch.update(firestore.collection('users').doc(userId), {
      'companyId': '',
      'role': 'user',
      'membership': 'active',
    });
    batch.delete(reference(firestore, userId));
    await batch.commit();
  }
}
