import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:survey_app_ks/login/login.dart';

class DeleteAccountButton extends StatelessWidget {
  final bool isSuperadmin;
  const DeleteAccountButton({Key? key, required this.isSuperadmin})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isSuperadmin ? Colors.grey : Colors.red,
        ),
        onPressed:
            isSuperadmin ? null : () => _confirmAndDeleteAccount(context),
        child: Text(
          'delete_account'.tr(),
          style: TextStyle(
            color: isSuperadmin ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }

  void _confirmAndDeleteAccount(BuildContext context) async {
    final User? user = FirebaseAuth.instance.currentUser;

    bool confirm = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('confirm'.tr()),
              content: Text('delete_account_warning'.tr()),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    'cancel'.tr(),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text('delete'.tr(),
                      style: const TextStyle(color: Colors.red)),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirm) return;

    await deleteUserFirestoreData(user!.uid);

    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const LoginPage(),
      ),
      (Route<dynamic> route) => false,
    );
  }

  Future<void> deleteUserFirestoreData(String userId) async {
    await _deleteCollectionData('appointments', userId);
    await _deleteCollectionData('participants', userId);
    await _deleteCollectionData('surveys', userId);
    await _deleteCollectionData('users', userId);
  }

  Future<void> _deleteCollectionData(String collection, String userId) async {
    final collectionRef = FirebaseFirestore.instance.collection(collection);
    final querySnapshot =
        await collectionRef.where('userId', isEqualTo: userId).get();

    for (final doc in querySnapshot.docs) {
      await doc.reference.delete();
    }
  }
}
