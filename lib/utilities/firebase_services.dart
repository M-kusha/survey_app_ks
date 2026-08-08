import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Reads of the signed-in user's profile, plus lookups of other users.
///
/// The signed-in user's document is fetched once and cached. Role, company and
/// display name all live in that single document, and the app asks for one or
/// another of them on nearly every screen — previously as a separate Firestore
/// read each time, which is the main driver of read volume in the app.
///
/// The cache is static because callers construct `FirebaseServices()` ad hoc
/// rather than sharing one instance; a per-instance cache would never be hit.
/// It is keyed by uid so a different user can never read a stale profile, and
/// [invalidateCache] must still be called on sign-out so a signed-out user's
/// details do not linger in memory.
class FirebaseServices {
  FirebaseServices({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  static String? _cachedUid;
  static Map<String, dynamic>? _cachedProfile;

  /// Drops the cached profile. Call on sign-out and on account deletion.
  static void invalidateCache() {
    _cachedUid = null;
    _cachedProfile = null;
  }

  Future<Map<String, dynamic>?> _currentProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    if (_cachedUid == uid && _cachedProfile != null) return _cachedProfile;

    final snapshot = await _db.collection('users').doc(uid).get();
    final data = snapshot.data();
    if (data == null) return null;

    _cachedUid = uid;
    _cachedProfile = data;
    return data;
  }

  /// Whether the signed-in user may administer surveys and appointments.
  ///
  /// This is a convenience for hiding UI only. It is not a security boundary —
  /// Firestore rules are what actually keep a non-admin from writing.
  Future<bool> fetchAdminStatus() async {
    final role = (await _currentProfile())?['role'] as String?;
    return role == 'admin' || role == 'moderator' || role == 'superadmin';
  }

  Future<bool> isSuperAdminUser() async =>
      ((await _currentProfile())?['role'] as String?) == 'superadmin';

  /// The company the signed-in user belongs to, or `null` if unknown.
  ///
  /// This is the single source of truth. Earlier builds also kept a copy in
  /// `SharedPreferences` that nothing ever wrote, so every read came back null
  /// and appointment creation failed on it.
  Future<String?> currentCompanyId() async {
    final companyId = (await _currentProfile())?['companyId'] as String?;
    return (companyId == null || companyId.isEmpty) ? null : companyId;
  }

  Future<String> fetchUserNameById(String userId) async {
    if (userId.isEmpty) return 'Unknown';
    final snapshot = await _db.collection('users').doc(userId).get();
    return snapshot.data()?['fullName'] as String? ?? 'Unknown';
  }

  Future<String> fetchProfileImage(String userId) async {
    if (userId.isEmpty) return '';
    final snapshot = await _db.collection('users').doc(userId).get();
    return snapshot.data()?['profileImage'] as String? ?? '';
  }
}
