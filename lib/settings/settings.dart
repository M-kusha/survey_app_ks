import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:survey_app_ks/login/login.dart';
import 'package:survey_app_ks/settings/daten_schutz.dart';
import 'package:survey_app_ks/settings/email_options.dart';
import 'package:survey_app_ks/settings/font_size_options.dart';
import 'package:survey_app_ks/settings/font_size_provider.dart';
import 'package:survey_app_ks/settings/language_options.dart';
import 'package:survey_app_ks/settings/notifications_options.dart';
import 'package:survey_app_ks/settings/text_to_speach_options.dart';
import 'package:survey_app_ks/settings/theme_options.dart';
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
  @override
  void initState() {
    super.initState();
    SettingsController settingsController = SettingsController();
    settingsController.getFontSize().then((value) {
      setState(() {
        EasyLocalization.of(context)!.setLocale(context.locale);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            centerTitle: true,
            title: Text(
              'settings'.tr(),
            ),
          ),
          body: Container(
            padding: const EdgeInsets.all(10),
            child: ListView(
              children: [
                NotificationsOptions(
                  icon: Icons.notifications,
                  title: 'global_notifications'.tr(),
                ),
                dividerSettings,
                EmailOptions(
                  icon: Icons.email,
                  title: 'email_notifications'.tr(),
                ),
                dividerSettings,
                TTSOptions(
                  icon: Icons.settings_voice,
                  title: 'text_to_speech'.tr(),
                ),
                dividerSettings,
                ThemeOptionsWidget(
                    icon: Icons.color_lens, title: 'dark_mode'.tr()),
                dividerSettings,
                LanguageOptionsWidget(
                    icon: Icons.translate_outlined, title: 'language'.tr()),
                dividerSettings,
                SizeOptions(
                  icon: Icons.text_fields,
                  title: 'font_size'.tr(),
                ),
                dividerSettings,
                DatenSchutzOptionsWidget(
                  icon: Icons.security,
                  title: 'datenschutz'.tr(),
                ),
                dividerSettings,
                const SizedBox(height: 30),
                Center(
                  child: OutlinedButton(
                    style: ButtonStyle(
                      padding: MaterialStateProperty.all(
                          const EdgeInsets.symmetric(horizontal: 100)),
                      shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18.0),
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const LoginPage(
                                  message: '',
                                )),
                      );
                    },
                    child: Text('log_out'.tr(),
                        style: TextStyle(fontSize: fontSize)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
