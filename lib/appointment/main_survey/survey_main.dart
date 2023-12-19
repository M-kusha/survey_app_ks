import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:survey_app_ks/appointment/create_survey/create_survey_step_4.dart';
import 'package:survey_app_ks/appointment/main_survey/survey_action_field.dart';
import 'package:survey_app_ks/appointment/main_survey/survey_create_button.dart';
import 'package:survey_app_ks/appointment/main_survey/survey_list.dart';
import 'package:survey_app_ks/settings/font_size_provider.dart';
import 'package:survey_app_ks/utilities/tablet_size.dart';

class SurveyPageUI extends StatefulWidget {
  const SurveyPageUI({super.key});

  @override
  State<SurveyPageUI> createState() => _SurveyPageUIState();
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 80);
}

enum SortingOption {
  mostParticipants,
  leastParticipants,
}

class _SurveyPageUIState extends State<SurveyPageUI> {
  int focusIndex = -1;
  bool isSearching = false;
  String searchQuery = '';

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

  int selectedSortOption = 0;
  bool _isSearching = false;
  TextEditingController searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);
    return Scaffold(
      // drawer: NavDrawer(theme: Theme.of(context)),
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
            : Text('appointment'.tr(),
                style: TextStyle(fontSize: timeFontSize + 3)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 22.0),
          Column(
            children: [
              buildCreateSurveyButton(context),
            ],
          ),
          buildExpandedField(context, isSearching, searchQuery),
        ],
      ),
      // bottomNavigationBar: const BottomNavigation(
      //   initialIndex: 0,
      // ),
    );
  }

  PopupMenuButton<int> buildPopupMenuButton(BuildContext context) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);
    return PopupMenuButton(
      icon: Icon(Icons.sort_by_alpha_sharp, size: timeFontSize * 1.5),
      itemBuilder: (BuildContext context) => [
        buildPopupMenuItem(
          'Most participants',
          0,
          context,
          () {
            setState(() {
              surveyList.sort((a, b) =>
                  b.participants.length.compareTo(a.participants.length));
            });
            Navigator.pop(context);
          },
        ),
        buildPopupMenuItem(
          'Least participants',
          1,
          context,
          () {
            setState(() {
              surveyList.sort((a, b) =>
                  a.participants.length.compareTo(b.participants.length));
            });
            Navigator.pop(context);
          },
        ),
        buildPopupMenuItem(
          'Expiration Date (Ascending)',
          2,
          context,
          () {
            setState(() {
              surveyList
                  .sort((a, b) => a.expirationDate.compareTo(b.expirationDate));
            });
            Navigator.pop(context);
          },
        ),
        buildPopupMenuItem(
          'Expiration Date (Descending)',
          3,
          context,
          () {
            setState(() {
              surveyList
                  .sort((a, b) => b.expirationDate.compareTo(a.expirationDate));
            });
            Navigator.pop(context);
          },
        ),
      ],
    );
  }

  PopupMenuItem<int> buildPopupMenuItem(
      String text, int value, BuildContext context, Function sortFunction) {
    return PopupMenuItem(
      child: RadioListTile(
        title: Text(text),
        value: value,
        activeColor: Colors.blue,
        groupValue: selectedSortOption,
        controlAffinity: ListTileControlAffinity.trailing,
        onChanged: (value) {
          setState(() {
            selectedSortOption = value!;
            sortFunction();
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
