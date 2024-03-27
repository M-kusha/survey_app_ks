import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseServices {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<bool> fetchAdminStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return false;
    }
    final userId = user.uid;
    final doc = await _db.collection('users').doc(userId).get();
    final role = doc.data()?['role'] as String?;
    return role == 'admin';
  }

  Future<String> fetchUserNameById(String userId) async {
    var userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (userDoc.exists) {
      return userDoc.data()?['fullName'] ?? 'Unknown';
    } else {
      return 'Unknown';
    }
  }

  Future<String> fetchProfileImage(String userId) async {
    if (userId.isNotEmpty) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      return (userDoc.data() as Map<String, dynamic>)['profileImage'] ?? '';
    }
    return '';
  }

  Future<String> fetchUserCompanyId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return '';
    }
    final userId = user.uid;
    final doc = await _db.collection('users').doc(userId).get();
    return doc.data()?['companyId'] as String? ?? '';
  }
}
