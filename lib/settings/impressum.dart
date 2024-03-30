import 'package:echomeet/settings/font_size_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ImpressumOptionsWidget extends StatefulWidget {
  final IconData icon;
  final String title;

  const ImpressumOptionsWidget(
      {super.key, required this.icon, required this.title});

  @override
  ImpressumOptionsWidgetState createState() => ImpressumOptionsWidgetState();
}

class ImpressumOptionsWidgetState extends State<ImpressumOptionsWidget> {
  @override
  Widget build(BuildContext context) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              setState(() {});
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
        ],
      ),
    );
  }
}
