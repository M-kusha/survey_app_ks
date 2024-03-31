import 'package:echomeet/settings/font_size_provider.dart';
import 'package:echomeet/utilities/settings_controller.dart';
import 'package:echomeet/utilities/text_style.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SizeOptions extends StatefulWidget {
  final IconData icon;
  final String title;

  const SizeOptions({
    super.key,
    required this.icon,
    required this.title,
  });

  @override
  SizeOptionsState createState() => SizeOptionsState();
}

class SizeOptionsState extends State<SizeOptions> {
  SettingsController settingsController = SettingsController();
  double _fontSize = 16;
  bool _isExpandedFont = false;

  @override
  void initState() {
    super.initState();
    settingsController.getFontSize().then((value) {
      setState(() {
        _fontSize = value;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    Color buttonColor = getButtonColor(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _isExpandedFont = !_isExpandedFont;
              });
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(widget.icon, size: _fontSize + 15),
                    const SizedBox(
                      width: 10,
                    ),
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: _fontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Icon(Icons.arrow_drop_down, size: _fontSize + 15),
              ],
            ),
          ),
          if (_isExpandedFont)
            Container(
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Slider(
                value: _fontSize,
                activeColor: buttonColor,
                min: 12,
                max: 22,
                label: _fontSize.round().toString(),
                onChanged: (double value) {
                  setState(() {
                    _fontSize = value;
                  });
                  Provider.of<FontSizeProvider>(context, listen: false)
                      .setFontSize(value);

                  settingsController.saveFontSize(value);
                },
              ),
            ),
        ],
      ),
    );
  }
}
