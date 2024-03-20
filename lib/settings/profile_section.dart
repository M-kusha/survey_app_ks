import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:survey_app_ks/utilities/reusable_widgets.dart';
import 'package:survey_app_ks/utilities/text_style.dart';

class ProfileSection extends StatefulWidget {
  final String userId;

  const ProfileSection({Key? key, required this.userId}) : super(key: key);

  @override
  State<ProfileSection> createState() => _ProfileSectionState();
}

class _ProfileSectionState extends State<ProfileSection> {
  bool _isUploading = false;
  Stream<DocumentSnapshot> getUserDataStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .snapshots();
  }

  Future<void> _pickAndUploadImage() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    File file = File(image.path);

    setState(() {
      _isUploading = true;
    });

    try {
      String userId = widget.userId;
      String filePath = 'profile_images/$userId.jpg';
      await FirebaseStorage.instance.ref(filePath).putFile(file);

      String downloadURL =
          await FirebaseStorage.instance.ref(filePath).getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'profileImage': downloadURL,
      });
      if (!context.mounted) return;
      UIUtils.showSnackBar(context, 'profile_image_uploaded'.tr());
    } catch (e) {
      if (!context.mounted) return;
      UIUtils.showSnackBar(context, 'error_updating_profile_image'.tr());
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Color buttonColor = getButtonColor(context);
    Color listCameraColor = getCameraColor(context);

    return StreamBuilder<DocumentSnapshot>(
      stream: getUserDataStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CustomLoadingWidget(loadingText: 'loading'));
        }

        if (!snapshot.hasData) {
          return const Center(child: Text("No user data found"));
        }

        var userData = snapshot.data!.data() as Map<String, dynamic>?;
        String userName = userData?['fullName'] ?? 'No Name';
        String userEmail = userData?['email'] ?? 'No Email';
        String? userProfilePic = userData?['profileImage'];

        return Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickAndUploadImage,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.grey.shade200,
                          backgroundImage:
                              !_isUploading && userProfilePic != null
                                  ? NetworkImage(userProfilePic)
                                  : null,
                          child: _isUploading
                              ? CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      buttonColor))
                              : null,
                        ),
                        if (userProfilePic == null && !_isUploading)
                          Container(
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.camera_alt,
                              size: 40.0,
                              color: listCameraColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    userName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    userEmail,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
