import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:survey_app_ks/appointments/appointment_data.dart';
import 'package:survey_app_ks/utilities/colors.dart';
import 'package:survey_app_ks/utilities/reusable_widgets.dart';
import 'package:url_launcher/url_launcher.dart';

Future<dynamic> userProfile(
    BuildContext context, AppointmentParticipants participant) {
  return showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0)), // Rounded corners
        child: Container(
          padding: const EdgeInsets.all(20.0),
          child: FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(participant.userId)
                .get(),
            builder: (BuildContext context,
                AsyncSnapshot<DocumentSnapshot> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.data() == null) {
                return const Text("No data available",
                    textAlign: TextAlign.center);
              }

              var userDoc = snapshot.data!.data() as Map<String, dynamic>;
              var fullName = userDoc['fullName'] ?? 'No Name';
              var email = userDoc['email'] ?? 'No Email';
              var profileImageUrl = userDoc['profileImage'] ?? '';

              return Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: profileImageUrl.isNotEmpty
                        ? NetworkImage(profileImageUrl)
                        : null,
                    backgroundColor: Colors.grey.shade200,
                    child: profileImageUrl.isEmpty
                        ? const Icon(Icons.person, size: 40, color: Colors.grey)
                        : null,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_outline,
                          color: ThemeBasedAppColors.getColor(
                              context, 'buttonColor')),
                      const SizedBox(width: 10),
                      Text(fullName,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () async {
                      final emailUri = Uri(
                        scheme: 'mailto',
                        path: email,
                      );
                      if (await canLaunchUrl(emailUri)) {
                        await launchUrl(emailUri);
                      } else {
                        if (!context.mounted) return;
                        UIUtils.showSnackBar(context, 'Could not launch email');
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.email_outlined,
                            color: ThemeBasedAppColors.getColor(
                                context, 'buttonColor')),
                        const SizedBox(width: 10),
                        Text(email, style: const TextStyle(fontSize: 16)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              );
            },
          ),
        ),
      );
    },
  );
}
