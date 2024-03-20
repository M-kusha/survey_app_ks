import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:survey_app_ks/login/login.dart';
import 'package:survey_app_ks/settings/daten_schutz.dart';
import 'package:survey_app_ks/settings/email_options.dart';
import 'package:survey_app_ks/settings/font_size_options.dart';
import 'package:survey_app_ks/settings/language_options.dart';
import 'package:survey_app_ks/settings/notifications_options.dart';
import 'package:survey_app_ks/settings/password_change.dart';
import 'package:survey_app_ks/settings/profile_section.dart';
import 'package:survey_app_ks/settings/text_to_speach_options.dart';
import 'package:survey_app_ks/settings/theme_options.dart';
import 'package:survey_app_ks/utilities/colors.dart';
import 'package:survey_app_ks/utilities/reusable_widgets.dart';
import 'package:survey_app_ks/utilities/settings_controller.dart';
import 'package:survey_app_ks/utilities/text_style.dart';

const double fontMediumSize = 14;

class SettingsPageUI extends StatefulWidget {
  final AdaptiveThemeMode? savedThemeMode;
  const SettingsPageUI({super.key, this.savedThemeMode});

  @override
  State<SettingsPageUI> createState() => _SettingsPageUIState();
}

class _SettingsPageUIState extends State<SettingsPageUI> {
  double currentFontSize = fontMediumSize;
  String userID = '';

  @override
  void initState() {
    super.initState();
    SettingsController settingsController = SettingsController();
    _initPage();

    settingsController.getFontSize().then((value) {
      setState(() {
        EasyLocalization.of(context)!.setLocale(context.locale);
      });
    });
  }

  void _initPage() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final userId = currentUser.uid;

      if (userId.isNotEmpty) {
        setState(() {
          userID = userId;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            centerTitle: true,
            title: Text('settings'.tr()),
          ),
          body: Container(
            padding: const EdgeInsets.all(10),
            child: ListView(
              children: [
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shadowColor:
                      ThemeBasedAppColors.getColor(context, 'buttonColor'),
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          child: ProfileSection(
                            userId: userID,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: IconButton(
                          icon: const Icon(Icons.settings),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const PasswordChanger()),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Card(
                  shadowColor:
                      ThemeBasedAppColors.getColor(context, 'buttonColor'),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      NotificationsOptions(
                        icon: Icons.notifications,
                        title: 'global_notifications'.tr(),
                      ),
                      sizedBoxSettings,
                      EmailOptions(
                        icon: Icons.email,
                        title: 'email_notifications'.tr(),
                      ),
                      sizedBoxSettings,
                      TTSOptions(
                        icon: Icons.settings_voice,
                        title: 'text_to_speech'.tr(),
                      ),
                      ThemeOptionsWidget(
                        icon: Icons.color_lens,
                        title: 'dark_mode'.tr(),
                      ),
                      sizedBoxSettings,
                    ],
                  ),
                ),
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shadowColor:
                      ThemeBasedAppColors.getColor(context, 'buttonColor'),
                  child: Column(
                    children: [
                      DatenSchutzOptionsWidget(
                        icon: Icons.security,
                        title: 'datenschutz'.tr(),
                      ),
                      sizedBoxSettings,
                      LanguageOptionsWidget(
                        icon: Icons.translate_outlined,
                        title: 'language'.tr(),
                      ),
                      sizedBoxSettings,
                      SizeOptions(
                        icon: Icons.text_fields,
                        title: 'font_size'.tr(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
          bottomNavigationBar: buildBottomElevatedButton(
            context: context,
            onPressed: _onNextPressed,
            buttonText: 'log_out',
          ),
        );
      },
    );
  }

  void _onNextPressed() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LoginPage(
          message: '',
        ),
      ),
    );
  }
}
