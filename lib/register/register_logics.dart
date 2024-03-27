import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

enum ProfileType { user, company }

class RegisterLogic {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController fullnameController = TextEditingController();
  final TextEditingController birthdateController = TextEditingController();
  final TextEditingController companyNameController = TextEditingController();

  ProfileType profileType = ProfileType.user;
  String? selectedCompanyName;
  File? profileImage;

  void setProfileImage(File? image) {
    profileImage = image;
  }

  Future<void> registerUser({String? companyId}) async {
    UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
      email: emailController.text.trim(),
      password: passwordController.text.trim(),
    );

    final User user = userCredential.user!;
    final String uid = user.uid;
    String? imageUrl;

    if (profileImage != null) {
      imageUrl = await _uploadProfileImage(uid);
    }

    Map<String, dynamic> userData = {
      'fullName': fullnameController.text.trim(),
      'birthdate': birthdateController.text.trim(),
      'email': emailController.text.trim(),
      'role': profileType == ProfileType.company ? 'superadmin' : 'user',
      'createdAt': FieldValue.serverTimestamp(),
      if (profileType == ProfileType.company && selectedCompanyName != null)
        'companyName': selectedCompanyName,
      if (companyId != null) 'companyId': companyId,
      if (imageUrl != null) 'profileImage': imageUrl,
    };

    await FirebaseFirestore.instance.collection('users').doc(uid).set(userData);
  }

  Future<String> registerCompany() async {
    var companyDoc = FirebaseFirestore.instance.collection('companies').doc();
    await companyDoc.set({
      'name': companyNameController.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return companyDoc.id;
  }

  Future<List<Map<String, dynamic>>> searchCompanies(String query) async {
    final querySnapshot =
        await FirebaseFirestore.instance.collection('companies').get();
    return querySnapshot.docs
        .map((doc) => {
              'id': doc.id,
              'name': doc.data()['name'] as String,
            })
        .where((company) => company['name']
            .toString()
            .toLowerCase()
            .contains(query.toLowerCase()))
        .toList();
  }

  Future<String> _uploadProfileImage(String uid) async {
    final storageRef =
        FirebaseStorage.instance.ref().child('profile_images/$uid');
    final uploadTask = storageRef.putFile(profileImage!);
    final snapshot = await uploadTask.whenComplete(() => null);
    return await snapshot.ref.getDownloadURL();
  }

  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    fullnameController.dispose();
    birthdateController.dispose();
    companyNameController.dispose();
  }
}
