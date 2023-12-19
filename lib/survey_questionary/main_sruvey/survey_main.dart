import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:survey_app_ks/settings/font_size_provider.dart';
import 'package:survey_app_ks/survey_questionary/main_sruvey/survey_action_field.dart';
import 'package:survey_app_ks/survey_questionary/main_sruvey/survey_create_button.dart';
import 'package:survey_app_ks/survey_questionary/main_sruvey/survey_list.dart';
import 'package:survey_app_ks/utilities/tablet_size.dart';
import 'package:provider/provider.dart';

class QuestionarySurveyPageUI extends StatefulWidget {
  const QuestionarySurveyPageUI({super.key});

  @override
  State<QuestionarySurveyPageUI> createState() =>
      _QuestionarySurveyPageUIState();
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 80);
}

class _QuestionarySurveyPageUIState extends State<QuestionarySurveyPageUI> {
  int focusIndex = -1;
  bool isSearching = false;
  String searchQuery = '';

  SortingOption selectedSortOption = SortingOption.mostParticipants;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    searchController.dispose();
  }

  void _onSearchTextChanged(String text) async {
    setState(() {
      searchQuery = text;
    });
  }

  bool _isSearching = false;
  TextEditingController searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);
    return Scaffold(
      //drawer: NavDrawer(theme: Theme.of(context)),
      appBar: AppBar(
        actions: [
          buildPopupMenuButton(
            context,
          ),
          buildSearchBar(),
        ],
        title: _isSearching
            ? ActionField(
                isSearching: _isSearching,
                searchController: searchController,
                onSearchTextChanged: _onSearchTextChanged,
              )
            : Text('surveys'.tr(),
                style: TextStyle(fontSize: timeFontSize + 3)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 22.0),
          Column(
            children: [
              buildCreateQuestionarySurveyButton(context),
            ],
          ),
          buildExpandedField(
              context, _isSearching, searchQuery, selectedSortOption),
        ],
      ),
    );
  }

  PopupMenuButton<SortingOption> buildPopupMenuButton(BuildContext context) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);
    return PopupMenuButton<SortingOption>(
      itemBuilder: (context) => [
        buildPopupMenuItem(
          'mostParticipants'.tr(),
          SortingOption.mostParticipants,
          context,
        ),
        buildPopupMenuItem(
          'leastParticipants'.tr(),
          SortingOption.leastParticipants,
          context,
        ),
        buildPopupMenuItem(
          'mostrecent'.tr(),
          SortingOption.mostRecent,
          context,
        ),
        buildPopupMenuItem(
          'experiationasc'.tr(),
          SortingOption.expirationDateAscending,
          context,
        ),
        buildPopupMenuItem(
          'expirationdesc'.tr(),
          SortingOption.expirationDateDescending,
          context,
        ),
      ],
      icon: Icon(Icons.sort_by_alpha_sharp, size: timeFontSize * 1.5),
      offset: const Offset(0, 100),
    );
  }

  PopupMenuItem<SortingOption> buildPopupMenuItem(
      String text, SortingOption value, BuildContext context) {
    return PopupMenuItem(
      child: RadioListTile<SortingOption>(
        title: Text(text),
        value: value,
        activeColor: Colors.blue,
        groupValue: selectedSortOption,
        controlAffinity: ListTileControlAffinity.trailing,
        onChanged: (SortingOption? newValue) {
          setState(() {
            selectedSortOption = newValue!;
            // Update your sorting logic here
          });
        },
      ),
    );
  }

  Widget buildSearchBar() {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);
    return _isSearching
        ? IconButton(
            icon: Icon(
              Icons.close,
              size: timeFontSize * 1.5,
            ),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                searchController.clear();
              });
            },
          )
        : IconButton(
            icon: Icon(
              Icons.search,
              size: timeFontSize * 1.5,
            ),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
              });
            },
          );
  }
}
