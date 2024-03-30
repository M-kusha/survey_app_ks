import 'package:echomeet/survey_pages/utilities/sorting.dart';
import 'package:echomeet/utilities/text_style.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class SortingWidget extends StatelessWidget {
  final int selectedSortOption;
  final Function(int) onSortOptionSelected;

  const SortingWidget({
    super.key,
    required this.selectedSortOption,
    required this.onSortOptionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final buttonColor = getButtonColor(context);

    return CustomPopupMenuButton(
        buttonColor: buttonColor,
        selectedOption: selectedSortOption,
        onOptionSelected: onSortOptionSelected,
        menuItems: [
          PopupMenuItemModel(
            text: 'sort_newest'.tr(),
            value: 0,
            icon: Icons.new_releases,
          ),
          PopupMenuItemModel(
            text: 'sort_oldest'.tr(),
            value: 1,
            icon: Icons.history,
          ),
          PopupMenuItemModel(
            text: 'sort_completed'.tr(),
            value: 2,
            icon: Icons.check_circle,
          ),
          PopupMenuItemModel(
            text: 'sort_uncompleted'.tr(),
            value: 3,
            icon: Icons.remove_circle,
          ),
        ],
        listTileColor: getListTileColor(context));
  }
}
