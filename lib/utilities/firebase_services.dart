import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseServices {
  FirebaseServices({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  static String? _cachedUid;
  static Map<String, dynamic>? _cachedProfile;

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

  Future<bool> fetchAdminStatus() async {
    final role = (await _currentProfile())?['role'] as String?;
    return role == 'admin' || role == 'moderator' || role == 'superadmin';
  }

  Future<bool> isSuperAdminUser() async =>
      ((await _currentProfile())?['role'] as String?) == 'superadmin';

  Future<bool> canManagePeople() async {
    final role = (await _currentProfile())?['role'] as String?;
    return role == 'admin' || role == 'superadmin';
  }

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
