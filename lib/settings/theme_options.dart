import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:survey_app_ks/settings/font_size_provider.dart';
import 'package:survey_app_ks/utilities/settings_controller.dart';

class ThemeOptionsWidget extends StatefulWidget {
  final IconData icon;
  final String title;

  const ThemeOptionsWidget(
      {super.key, required this.icon, required this.title});

  @override
  ThemeOptionsWidgetState createState() => ThemeOptionsWidgetState();
}

class ThemeOptionsWidgetState extends State<ThemeOptionsWidget> {
  bool _light = true;

  @override
  void initState() {
    super.initState();
    SettingsController().getThemeBool().then((value) {
      setState(() {
        _light = value;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(
          children: [
            Icon(widget.icon, size: fontSize + 15),
            const SizedBox(
              width: 10,
            ),
            Text(
              widget.title,
              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        AnimatedSwitcher(
          duration: const Duration(seconds: 1),
          child: Transform.scale(
            scale: 0.7,
            child: CupertinoSwitch(
              activeColor: Colors.blue,
              trackColor: Colors.grey,
              value: _light,
              onChanged: (value) {
                setState(() {
                  _light = value;
                  if (_light) {
                    AdaptiveTheme.of(context).setDark();
                  } else {
                    AdaptiveTheme.of(context).setLight();
                  }
                  SettingsController().saveThemeBool(_light);
                });
              },
            ),
          ),
        ),
      ]),
    );
  }
}
