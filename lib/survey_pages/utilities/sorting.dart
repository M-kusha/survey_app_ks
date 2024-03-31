import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/settings/font_size_provider.dart';
import 'package:echomeet/utilities/tablet_size.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CustomPopupMenuButton extends StatelessWidget {
  final Color buttonColor;
  final Color listTileColor;
  final int selectedOption;
  final Function(int) onOptionSelected;
  final List<PopupMenuItemModel> menuItems;

  const CustomPopupMenuButton({
    super.key,
    required this.buttonColor,
    required this.listTileColor,
    required this.selectedOption,
    required this.onOptionSelected,
    required this.menuItems,
  });

  @override
  Widget build(BuildContext context) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);

    return PopupMenuButton<int>(
      icon: Icon(Icons.sort_by_alpha_sharp,
          color: buttonColor, size: timeFontSize * 1.8),
      offset: const Offset(0, 60),
      onSelected: onOptionSelected,
      itemBuilder: (BuildContext context) => menuItems.map((item) {
        return PopupMenuItem<int>(
          value: item.value,
          child: ListTile(
            leading: Icon(item.icon,
                color:
                    selectedOption == item.value ? buttonColor : listTileColor),
            title: Text(
              item.text.tr(),
              style: TextStyle(
                color:
                    selectedOption == item.value ? buttonColor : listTileColor,
                fontWeight: selectedOption == item.value
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
            trailing: selectedOption == item.value
                ? Icon(Icons.check, color: buttonColor, size: 17.0)
                : null,
          ),
        );
      }).toList(),
    );
  }
}

class PopupMenuItemModel {
  final String text;
  final int value;
  final IconData icon;

  PopupMenuItemModel(
      {required this.text, required this.value, required this.icon});
}
