import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/settings/font_size_provider.dart';
import 'package:echomeet/utilities/tablet_size.dart';
import 'package:echomeet/utilities/text_style.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ActionField extends StatefulWidget {
  final bool isSearching;
  final TextEditingController searchController;
  final void Function(String) onSearchTextChanged;

  const ActionField({
    Key? key,
    required this.isSearching,
    required this.searchController,
    required this.onSearchTextChanged,
  }) : super(key: key);

  @override
  ActionFieldState createState() => ActionFieldState();
}

class ActionFieldState extends State<ActionField> {
  String searchQuery = '';

  @override
  void dispose() {
    widget.onSearchTextChanged("");
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);
    return widget.isSearching
        ? Center(
            child: TextField(
              cursorWidth: 2,
              controller: widget.searchController,
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
                widget.onSearchTextChanged(value);
              },
              decoration: InputDecoration(
                hintStyle: TextStyle(color: getButtonColor(context)),
                border: InputBorder.none,
                hintText: 'search'.tr(),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 1.0, horizontal: 24.0),
                filled: true,
                prefixIconColor: getButtonColor(context),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.circular(50),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: getButtonColor(context),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(50),
                ),
                alignLabelWithHint: false,
              ),
              textAlign: TextAlign.center,
            ),
          )
        : Text('${'surveys'.tr()} (${widget.searchController.text})',
            style: TextStyle(fontSize: timeFontSize));
  }
}
