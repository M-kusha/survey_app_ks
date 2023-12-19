import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:survey_app_ks/settings/font_size_provider.dart';
import 'package:survey_app_ks/utilities/settings_controller.dart';

class LanguageOptionsWidget extends StatefulWidget {
  final IconData icon;
  final String title;

  const LanguageOptionsWidget({
    Key? key,
    required this.icon,
    required this.title,
  }) : super(key: key);

  @override
  LanguageOptionsWidgetState createState() => LanguageOptionsWidgetState();
}

class LanguageOptionsWidgetState extends State<LanguageOptionsWidget> {
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    loadFontSize();
  }

  void _changeLanguage(BuildContext context, Locale locale) {
    EasyLocalization.of(context)!.setLocale(locale);
  }

  void loadFontSize() async {
    final settingsController = SettingsController();
    final fontSize = await settingsController.getFontSize();

    // ignore: use_build_context_synchronously
    Provider.of<FontSizeProvider>(context, listen: false).setFontSize(fontSize);
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final currentLocale = context.locale;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(widget.icon, size: fontSize + 15),
                    const SizedBox(
                      width: 10,
                    ),
                    Text(
                      widget.title,
                      style: TextStyle(
                          fontSize: fontSize, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Icon(Icons.arrow_drop_down, size: fontSize + 15),
              ],
            ),
          ),
          if (_isExpanded)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    spreadRadius: 1,
                    blurRadius: 1,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              margin: const EdgeInsets.only(top: 10),
              height: 100,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 0),
                itemCount:
                    EasyLocalization.of(context)!.supportedLocales.length,
                itemBuilder: (context, index) {
                  final locale =
                      EasyLocalization.of(context)!.supportedLocales[index];

                  return GestureDetector(
                    onTap: () => _changeLanguage(context, locale),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey.withOpacity(0.5),
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            height: 40,
                            width: 20,
                          ),
                          Text(
                            locale.languageCode.toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: fontSize,
                              color: locale == currentLocale
                                  ? Colors.blue
                                  : Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            locale.countryCode?.toUpperCase() ?? '',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: fontSize,
                              color: locale == currentLocale
                                  ? Colors.blue
                                  : Colors.grey,
                            ),
                          ),
                          const Spacer(),
                          if (locale == currentLocale)
                            Container(
                              height: 20,
                              width: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.blue,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(0.4),
                                    spreadRadius: 1,
                                    blurRadius: 1,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.check,
                                color: Colors.white,
                                size: fontSize,
                              ),
                            ),
                          const SizedBox(
                            height: 40,
                            width: 20,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
