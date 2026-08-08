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

  /// Creates the account, then the company (when registering one), then the
  /// profile document — in that order.
  ///
  /// The order is load-bearing. An earlier version created the company two
  /// screens earlier, before sign-up, which meant the write was unauthenticated
  /// and `companies` had to accept writes from anyone. It also left an orphaned
  /// company behind whenever somebody abandoned the flow before finishing.
  ///
  /// [existingCompanyId] is set when joining a company that already exists;
  /// leave it null when registering a new one.
  Future<void> registerUser({String? existingCompanyId}) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: emailController.text.trim(),
      password: passwordController.text.trim(),
    );

    final uid = userCredential.user!.uid;
    final registeringCompany = profileType == ProfileType.company;

    final companyId = registeringCompany
        ? await _createCompany(uid)
        : existingCompanyId;

    final imageUrl = profileImage != null ? await _uploadProfileImage(uid) : null;

    final userData = {
      'fullName': fullnameController.text.trim(),
      'birthdate': birthdateController.text.trim(),
      'email': emailController.text.trim(),
      // Security rules only accept 'superadmin' when the companyId names a
      // company this same user just created, so joining an existing company
      // cannot be used to award yourself admin.
      'role': registeringCompany ? 'superadmin' : 'user',
      'createdAt': FieldValue.serverTimestamp(),
      if (registeringCompany && selectedCompanyName != null)
        'companyName': selectedCompanyName,
      'companyId': ?companyId,
      'profileImage': ?imageUrl,
    };

    await FirebaseFirestore.instance.collection('users').doc(uid).set(userData);
  }

  /// Writes the company document, stamped with its creator.
  ///
  /// `createdBy` is what lets the security rules tell "I am registering my own
  /// new company" apart from "I am joining someone else's".
  Future<String> _createCompany(String uid) async {
    final companyDoc = FirebaseFirestore.instance.collection('companies').doc();
    await companyDoc.set({
      'name': companyNameController.text.trim(),
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return companyDoc.id;
  }

  Future<List<Map<String, dynamic>>> searchCompanies(String query) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('companies')
        .get();
    return querySnapshot.docs
        .map((doc) => {'id': doc.id, 'name': doc.data()['name'] as String})
        .where(
          (company) => company['name'].toString().toLowerCase().contains(
            query.toLowerCase(),
          ),
        )
        .toList();
  }

  Future<String> _uploadProfileImage(String uid) async {
    // Must match the path ProfileSection writes to. These used to differ by the
    // extension, so setting an avatar at sign-up and then changing it in
    // settings left two files in the bucket and orphaned the first.
    final storageRef = FirebaseStorage.instance.ref().child(
      'profile_images/$uid.jpg',
    );
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
