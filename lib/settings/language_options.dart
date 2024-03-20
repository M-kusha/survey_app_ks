import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:survey_app_ks/settings/font_size_provider.dart';
import 'package:survey_app_ks/utilities/text_style.dart';

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
  bool _isLanguageExpanded = false;
  final Map<String, String> _languageNames = {
    'en': 'English',
    'de': 'Deutsch',
    'sq': 'Shqip',
  };

  void _changeLanguage(BuildContext context, Locale locale) {
    context.setLocale(locale);
  }

  String _getLanguageFullName(Locale locale) {
    return _languageNames[locale.languageCode] ??
        locale.languageCode.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final fontSizeProvider = Provider.of<FontSizeProvider>(context);
    final currentLocale = context.locale;
    final List<Locale> locales = context.supportedLocales;
    Color buttonColor = getButtonColor(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _isLanguageExpanded = !_isLanguageExpanded;
              });
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(widget.icon, size: fontSizeProvider.fontSize + 15),
                    const SizedBox(width: 10),
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: fontSizeProvider.fontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Icon(
                  _isLanguageExpanded
                      ? Icons.arrow_drop_up
                      : Icons.arrow_drop_down,
                  size: fontSizeProvider.fontSize + 15,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (_isLanguageExpanded)
            Column(
              children: locales
                  .map((locale) => ListTile(
                        leading: CircleAvatar(
                          backgroundColor: buttonColor,
                          child: Text(
                            locale.languageCode.toUpperCase(),
                            style: TextStyle(
                              fontSize: fontSizeProvider.fontSize - 4,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        title: Text(
                          _getLanguageFullName(locale),
                          style: TextStyle(fontSize: fontSizeProvider.fontSize),
                        ),
                        trailing: locale == currentLocale
                            ? Icon(Icons.check_circle,
                                color: buttonColor,
                                size: fontSizeProvider.fontSize + 10)
                            : null,
                        onTap: () => _changeLanguage(context, locale),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }
}
