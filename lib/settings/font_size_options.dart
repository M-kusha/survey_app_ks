import 'package:echomeet/settings/font_size_provider.dart';
import 'package:echomeet/utilities/text_style.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SizeOptions extends StatefulWidget {
  final IconData icon;
  final String title;

  const SizeOptions({super.key, required this.icon, required this.title});

  @override
  SizeOptionsState createState() => SizeOptionsState();
}

class SizeOptionsState extends State<SizeOptions> {
  bool _isExpandedFont = false;

  @override
  Widget build(BuildContext context) {
    // Read straight from the provider so the slider and the rest of the app can
    // never show different sizes.
    final fontSizeProvider = context.watch<FontSizeProvider>();
    final fontSize = fontSizeProvider.fontSize;
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
                    Icon(widget.icon, size: fontSize + 15),
                    const SizedBox(width: 10),
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Icon(Icons.arrow_drop_down, size: fontSize + 15),
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
                value: fontSize,
                activeColor: buttonColor,
                min: fontMinSize,
                max: fontMaxSize,
                label: fontSize.round().toString(),
                onChanged: fontSizeProvider.setFontSize,
              ),
            ),
        ],
      ),
    );
  }
}
