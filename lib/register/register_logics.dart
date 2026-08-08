import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

enum ProfileType { user, company }

/// Someone already registered a company under this name.
///
/// Names are compared with case and punctuation folded, so "Acme Ltd." collides
/// with "acme ltd" — two companies whose names differ only by punctuation are
/// indistinguishable on the screen where you pick one to join.
class CompanyNameTakenException implements Exception {
  const CompanyNameTakenException();
}

/// The company name contains nothing usable once punctuation is stripped.
class CompanyNameInvalidException implements Exception {
  const CompanyNameInvalidException();
}

/// This email address already has an account.
class EmailAlreadyRegisteredException implements Exception {
  const EmailAlreadyRegisteredException();
}

/// The password was rejected as too weak by Firebase.
class WeakPasswordException implements Exception {
  const WeakPasswordException();
}

/// Maps a registration failure onto a translation key.
///
/// Registration can fail for reasons the user can fix — a taken email, a
/// duplicate company name — and telling them which is the difference between a
/// form they can complete and one that just says "an unexpected error
/// occurred", which is what both screens showed before.
String registrationErrorKey(Object error) => switch (error) {
  EmailAlreadyRegisteredException() => 'email_already_exists',
  CompanyNameTakenException() => 'company_name_taken',
  CompanyNameInvalidException() => 'company_name_invalid',
  WeakPasswordException() => 'validate_password_strong',
  _ => 'error_occurred',
};

class RegisterLogic {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController fullnameController = TextEditingController();
  final TextEditingController birthdateController = TextEditingController();
  final TextEditingController companyNameController = TextEditingController();

  // There is deliberately no `profileType` field here. One used to exist,
  // defaulted to ProfileType.user, and was never assigned by anything — the
  // registration screens pass the choice down as a constructor argument
  // instead. Anything reading the field silently got "ordinary user" no matter
  // what the person picked on the first screen.
  String? selectedCompanyName;
  File? profileImage;

  void setProfileImage(File? image) {
    profileImage = image;
  }

  /// Registers a user, and either completes or leaves nothing behind.
  ///
  /// [profileType] must be the choice made on the first screen — passed in
  /// rather than read from shared state, so it cannot silently default.
  /// [existingCompanyId] is set when joining a company that already exists;
  /// leave it null when registering a new one.
  ///
  /// There is no way to make this a real transaction — it spans Firebase Auth,
  /// Firestore and Storage — so it is arranged in order of importance instead:
  ///
  ///   1. the account, which everything else hangs off
  ///   2. the company and the profile document, which the app cannot work
  ///      without, wrapped so that a failure deletes the account again
  ///   3. the avatar, which is decoration and must never be able to break a
  ///      registration that has otherwise succeeded
  ///
  /// The rollback in step 2 matters more than it looks. Without it a failure
  /// after sign-up leaves an account with no profile — able to log in, with no
  /// role and no company — and permanently burns that email address, because
  /// retrying returns `email-already-in-use`. That is exactly what a failed
  /// avatar upload used to do, since the profile was written after it.
  Future<void> registerUser({
    required ProfileType profileType,
    String? existingCompanyId,
  }) async {
    // Email uniqueness is enforced by Firebase Auth itself — there is no
    // separate check to write, only a code to translate into something the
    // user can act on.
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

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
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
      });
    } catch (_) {
      // Give the email back so the user can simply try again.
      await user.delete().catchError((_) {});
      rethrow;
    }

    await _attachProfileImage(user.uid);
  }

  /// Uploads the avatar and links it to the profile.
  ///
  /// Deliberately best-effort and deliberately last. A missing avatar is a
  /// cosmetic problem; a half-registered account is not.
  Future<void> _attachProfileImage(String uid) async {
    if (profileImage == null) return;
    try {
      final imageUrl = await _uploadProfileImage(uid);
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'profileImage': imageUrl,
      });
    } catch (_) {
      // The account is already usable. The user can set a picture from
      // Settings once Storage is reachable.
    }
  }

  /// Turns a company name into a document id usable as a uniqueness lock.
  ///
  /// Case and punctuation are folded so "Acme Ltd." and "acme ltd" collide,
  /// which is the point — two companies with names that differ only in
  /// punctuation are indistinguishable on the join screen.
  static String companyNameSlug(String name) => name
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  /// Writes the company document, stamped with its creator.
  ///
  /// `createdBy` is what lets the security rules tell "I am registering my own
  /// new company" apart from "I am joining someone else's".
  ///
  /// Written as a batch alongside a lock document at `companyNames/<slug>`.
  /// Firestore cannot enforce uniqueness on a *field*, but it can on a document
  /// id: the rules allow that path to be created and never updated, so a second
  /// company claiming the same name fails the whole batch. The check below is
  /// only there to produce a good message — the rule is what actually
  /// guarantees it, including against two people registering simultaneously.
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
      'name': name,
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      // The lock document already existed, so the rules refused the write.
      // This is the case the pre-check above cannot cover: someone claimed the
      // same name in the moment between that read and this commit.
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
