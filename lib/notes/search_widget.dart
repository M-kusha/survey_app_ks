import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:survey_app_ks/settings/font_size_provider.dart';
import 'package:survey_app_ks/utilities/tablet_size.dart';
import 'package:survey_app_ks/utilities/text_style.dart';

class SearchWidget extends StatelessWidget {
  final bool isSearching;
  final TextEditingController searchController;
  final Function(String) onSearchTextChanged;

  const SearchWidget({
    super.key,
    required this.isSearching,
    required this.searchController,
    required this.onSearchTextChanged,
  });

  @override
  Widget build(BuildContext context) {
    final buttonColor = getButtonColor(context);
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);

    return IconButton(
      icon: Icon(
        isSearching ? Icons.close : Icons.search,
        size: timeFontSize * 1.8,
        color: buttonColor,
      ),
      onPressed: () {
        onSearchTextChanged('');
      },
    );
  }
}
