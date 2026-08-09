import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

enum ProfileType { user, company }

class CompanyNameTakenException implements Exception {
  const CompanyNameTakenException();
}

class CompanyNameInvalidException implements Exception {
  const CompanyNameInvalidException();
}

class EmailAlreadyRegisteredException implements Exception {
  const EmailAlreadyRegisteredException();
}

class WeakPasswordException implements Exception {
  const WeakPasswordException();
}

String registrationErrorKey(Object error) => switch (error) {
  EmailAlreadyRegisteredException() => 'email_already_exists',
  CompanyNameTakenException() => 'company_name_taken',
  CompanyNameInvalidException() => 'company_name_invalid',
  WeakPasswordException() => 'validate_password_strong',
  _ => 'error_occurred',
};

class RegisterLogic {
  late final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController fullnameController = TextEditingController();
  final TextEditingController birthdateController = TextEditingController();
  final TextEditingController companyNameController = TextEditingController();

  String? selectedCompanyName;
  File? profileImage;

  void setProfileImage(File? image) {
    profileImage = image;
  }

  Future<void> registerUser({
    required ProfileType profileType,
    String? existingCompanyId,
  }) async {
    final UserCredential userCredential;
    try {
      userCredential = await _auth.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      throw switch (e.code) {
        'email-already-in-use' => const EmailAlreadyRegisteredException(),
        'weak-password' => const WeakPasswordException(),
        _ => e,
      };
    }

    final user = userCredential.user!;
    final registeringCompany = profileType == ProfileType.company;

    try {
      final companyId = registeringCompany
          ? await _createCompany(user.uid)
          : existingCompanyId;

      final membership = registeringCompany || companyId == null
          ? 'active'
          : await _joinStatusFor(companyId);

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'membership': membership,
        'fullName': fullnameController.text.trim(),
        'birthdate': birthdateController.text.trim(),
        'email': emailController.text.trim(),

        'role': registeringCompany ? 'superadmin' : 'user',
        'createdAt': FieldValue.serverTimestamp(),
        if (registeringCompany && selectedCompanyName != null)
          'companyName': selectedCompanyName,
        'companyId': ?companyId,
      });
    } catch (_) {
      await user.delete().catchError((_) {});
      rethrow;
    }

    await _attachProfileImage(user.uid);
  }

  Future<String> _joinStatusFor(String companyId) async {
    final company = await FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .get();

    final policy = company.data()?['joinPolicy'] as String? ?? 'open';
    return policy == 'approval' ? 'pending' : 'active';
  }

  Future<void> _attachProfileImage(String uid) async {
    if (profileImage == null) return;
    try {
      final imageUrl = await _uploadProfileImage(uid);
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'profileImage': imageUrl,
      });
    } catch (_) {}
  }

  static String companyNameSlug(String name) => name
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  Future<String> _createCompany(String uid) async {
    final firestore = FirebaseFirestore.instance;
    final name = companyNameController.text.trim();
    final slug = companyNameSlug(name);

    if (slug.isEmpty) {
      throw const CompanyNameInvalidException();
    }

    final lockRef = firestore.collection('companyNames').doc(slug);
    if ((await lockRef.get()).exists) {
      throw const CompanyNameTakenException();
    }

    final companyDoc = firestore.collection('companies').doc();

    final batch = firestore.batch();
    batch.set(lockRef, {'companyId': companyDoc.id, 'createdBy': uid});
    batch.set(companyDoc, {
      'joinPolicy': 'open',
      'name': name,
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw const CompanyNameTakenException();
      }
      rethrow;
    }

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
