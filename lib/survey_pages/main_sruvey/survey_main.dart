import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:survey_app_ks/settings/font_size_provider.dart';
import 'package:survey_app_ks/survey_pages/main_sruvey/survey_action_field.dart';
import 'package:survey_app_ks/survey_pages/main_sruvey/survey_create_button.dart';
import 'package:survey_app_ks/survey_pages/main_sruvey/survey_list.dart';
import 'package:survey_app_ks/survey_pages/utilities/survey_data_provider.dart';
import 'package:survey_app_ks/survey_pages/utilities/survey_questionary_class.dart';
import 'package:survey_app_ks/utilities/colors.dart';
import 'package:survey_app_ks/utilities/firebase_services.dart';
import 'package:survey_app_ks/utilities/reusable_widgets.dart';
import 'package:survey_app_ks/utilities/tablet_size.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart';

class QuestionarySurveyPageUI extends StatefulWidget {
  const QuestionarySurveyPageUI({super.key});

  @override
  State<QuestionarySurveyPageUI> createState() =>
      _QuestionarySurveyPageUIState();
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 80);
}

class _QuestionarySurveyPageUIState extends State<QuestionarySurveyPageUI> {
  final int _surveysPerPage = 4;
  int focusIndex = -1;
  int _currentPage = 0;
  int selectedSortOption = 0;
  bool isSearching = false;
  bool _isAdmin = false;
  String searchQuery = '';
  late FirebaseServices _firebaseServices;
  bool _isLoading = false;

  @override
  void initState() {
    _firebaseServices = FirebaseServices();
    super.initState();
    _loadUserAndSurveys();
  }

  void _loadUserAndSurveys() async {
    final provider = Provider.of<SurveyDataProvider>(context, listen: false);
    _firebaseServices = Provider.of<FirebaseServices>(context, listen: false);
    setState(() {
      _isLoading = true;
    });

    await Provider.of<UserDataProvider>(context, listen: false)
        .loadCurrentUser();
    if (!context.mounted) return;
    final companyId = Provider.of<UserDataProvider>(context, listen: false)
            .currentUser
            ?.companyId ??
        '';

    if (companyId.isNotEmpty) {
      if (!context.mounted) return;
      Future.microtask(() => provider.loadSurveys(companyId).then((_) {
            final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
            provider.checkParticipationForCurrentUser(userId);
          }));
    }
    final isAdmin = await _firebaseServices.fetchAdminStatus();
    if (!mounted) return;
    setState(() {
      _isAdmin = isAdmin;
    });
    {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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

  TextEditingController searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);
    Color buttonColor = ThemeBasedAppColors.getColor(context, 'buttonColor');
    Color appbarColor = ThemeBasedAppColors.getColor(context, 'appbarColor');
    Color listTileColor =
        ThemeBasedAppColors.getColor(context, 'listTileColor');
    return Scaffold(
      appBar: AppBar(
        leading: buildPopupMenuButton(context, buttonColor, listTileColor),
        title: isSearching
            ? ActionField(
                isSearching: isSearching,
                searchController: searchController,
                onSearchTextChanged: _onSearchTextChanged,
              )
            : Text('surveys'.tr(),
                style: TextStyle(fontSize: timeFontSize * 1.5)),
        centerTitle: true,
        backgroundColor: appbarColor,
        actions: [
          buildSearchBar(buttonColor),
        ],
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          const SizedBox(height: 22.0),
          buildExpandedField(
            context,
            isSearching,
            searchQuery,
          ),
        ],
      ),
      floatingActionButton:
          _isAdmin ? buildCreateQuestionarySurveyButton(context) : null,
    );
  }

  PopupMenuItem<int> buildPopupMenuItem(BuildContext context, String text,
      int value, IconData icon, Color buttonColor, Color listTileColor) {
    bool isSelected = selectedSortOption == value;

    return PopupMenuItem(
      value: value,
      child: ListTile(
        leading: Icon(icon, color: isSelected ? buttonColor : listTileColor),
        title: Text(
          text.tr(),
          style: TextStyle(
            color: isSelected ? buttonColor : listTileColor,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        trailing: isSelected
            ? Icon(
                Icons.check,
                color: buttonColor,
                size: 17.0,
              )
            : null,
      ),
    );
  }

  PopupMenuButton<int> buildPopupMenuButton(
      BuildContext context, Color buttonColor, Color listTileColor) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);
    return PopupMenuButton<int>(
      icon: Icon(
        Icons.sort_by_alpha_sharp,
        color: buttonColor,
        size: timeFontSize * 1.8,
      ),
      offset: const Offset(0, 60),
      onSelected: (int result) {
        setState(() {
          selectedSortOption = result;
        });
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<int>>[
        buildPopupMenuItem(
            context, 'newest', 0, Icons.new_label, buttonColor, listTileColor),
        buildPopupMenuItem(
            context, 'oldest', 1, Icons.history, buttonColor, listTileColor),
        buildPopupMenuItem(context, 'exp_date_asc', 4, Icons.date_range_sharp,
            buttonColor, listTileColor),
        buildPopupMenuItem(context, 'exp_date_des', 5, Icons.date_range,
            buttonColor, listTileColor),
      ],
    );
  }

  Widget buildSearchBar(
    Color buttonColor,
  ) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);
    return isSearching
        ? IconButton(
            icon: Icon(
              Icons.close,
              size: timeFontSize * 1.8,
              color: buttonColor,
            ),
            onPressed: () {
              setState(() {
                isSearching = !isSearching;
                searchController.clear();
              });
            },
          )
        : IconButton(
            icon: Icon(
              Icons.search,
              size: timeFontSize * 1.8,
              color: buttonColor,
            ),
            onPressed: () {
              setState(() {
                isSearching = !isSearching;
              });
            },
          );
  }

  Widget buildExpandedField(
      BuildContext context, bool isSearching, String searchQuery) {
    final surveyListProvider = Provider.of<SurveyDataProvider>(context);
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);

    if (_isLoading) {
      return const Expanded(
        child: Center(child: CustomLoadingWidget(loadingText: 'loading')),
      );
    }

    List<Survey> filteredSurveys = surveyListProvider.surveys.where((survey) {
      final lowerCaseQuery = searchQuery.toLowerCase();
      return survey.surveyName.toLowerCase().contains(lowerCaseQuery) ||
          survey.id.toLowerCase().contains(lowerCaseQuery) ||
          format(survey.timeCreated).toLowerCase().contains(lowerCaseQuery);
    }).toList();

    switch (selectedSortOption) {
      case 0:
        filteredSurveys.sort((a, b) => b.timeCreated.compareTo(a.timeCreated));
        break;
      case 1:
        filteredSurveys.sort((a, b) => a.timeCreated.compareTo(b.timeCreated));
        break;
      case 2:
        filteredSurveys.sort((a, b) => a.deadline.compareTo(b.deadline));
        break;
      case 3:
        filteredSurveys.sort((b, a) => a.deadline.compareTo(b.deadline));
        break;
    }

    final totalPages = (filteredSurveys.length / _surveysPerPage).ceil();
    final startIndex = _currentPage * _surveysPerPage;
    final endIndex = startIndex + _surveysPerPage > filteredSurveys.length
        ? filteredSurveys.length
        : startIndex + _surveysPerPage;
    final surveysForCurrentPage = filteredSurveys.sublist(startIndex, endIndex);
    if (filteredSurveys.isEmpty) {
      return Expanded(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              isSearching
                  ? 'search_survey_or_test_not_found'.tr()
                  : 'no_test_surveys_yet'.tr(),
              style: TextStyle(fontSize: timeFontSize * 1.2),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    } else {
      return Expanded(
        child: Column(
          children: [
            Expanded(
              child: ListView.separated(
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 20.0),
                itemCount: surveysForCurrentPage.length,
                itemBuilder: (context, index) {
                  final survey = filteredSurveys[index];
                  final hasParticipated =
                      surveyListProvider.userParticipationStatus[survey.id] ??
                          false;
                  return SurveyListItem(
                    survey: surveysForCurrentPage[index],
                    isAdmin: _isAdmin,
                    hasParticipated: hasParticipated,
                  );
                },
              ),
            ),
            if (totalPages > 1)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_outlined),
                    onPressed: _currentPage > 0
                        ? () {
                            setState(() {
                              _currentPage--;
                            });
                          }
                        : null,
                  ),
                  Text('${'page'.tr()} ${_currentPage + 1} of $totalPages'),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_outlined),
                    onPressed: _currentPage < totalPages - 1
                        ? () {
                            setState(() {
                              _currentPage++;
                            });
                          }
                        : null,
                  ),
                ],
              ),
          ],
        ),
      );
    }
  }
}
