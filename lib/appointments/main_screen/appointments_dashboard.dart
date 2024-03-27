import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:survey_app_ks/appointments/appointment_data.dart';
import 'package:survey_app_ks/appointments/firebase/appointment_provider.dart';
import 'package:survey_app_ks/appointments/main_screen/appointment_search_field.dart';
import 'package:survey_app_ks/appointments/main_screen/create_appointment_button.dart';
import 'package:survey_app_ks/appointments/main_screen/appointment_list.dart';
import 'package:survey_app_ks/settings/font_size_provider.dart';
import 'package:survey_app_ks/survey_pages/utilities/survey_data_provider.dart';
import 'package:survey_app_ks/utilities/firebase_services.dart';
import 'package:survey_app_ks/utilities/reusable_widgets.dart';
import 'package:survey_app_ks/utilities/tablet_size.dart';
import 'package:survey_app_ks/utilities/text_style.dart';
import 'package:timeago/timeago.dart';

class AppointmentPageUI extends StatefulWidget {
  const AppointmentPageUI({super.key});

  @override
  State<AppointmentPageUI> createState() => AppointmentPageUIState();
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 80);
}

class AppointmentPageUIState extends State<AppointmentPageUI> {
  int focusIndex = -1;
  bool isSearching = false;
  String searchQuery = '';
  bool _isAdmin = false;
  int _currentPage = 0;
  final int _appointmentsPerPage = 4;
  bool _isLoading = false;

  late FirebaseServices _firebaseServices;
  @override
  void initState() {
    super.initState();
    _firebaseServices = Provider.of<FirebaseServices>(context, listen: false);
    _loadUserAndSurveys();
  }

  void _loadUserAndSurveys() async {
    setState(() => _isLoading = true);

    final provider =
        Provider.of<AppointmentDataProvider>(context, listen: false);
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    await Provider.of<UserDataProvider>(context, listen: false)
        .loadCurrentUser();
    if (!context.mounted) return;
    final companyId = Provider.of<UserDataProvider>(context, listen: false)
            .currentUser
            ?.companyId ??
        '';

    if (companyId.isNotEmpty) {
      await provider.loadAppointments(companyId);
      await provider.preloadUserParticipationStatus(userId);
    }

    final isAdmin = await _firebaseServices.fetchAdminStatus();

    setState(() {
      _isAdmin = isAdmin;
      _isLoading = false;
    });
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
      appBar: AppBar(
        leading: buildPopupMenuButton(context),
        title: _isSearching
            ? ActionField(
                isSearching: _isSearching,
                searchController: searchController,
                onSearchTextChanged: _onSearchTextChanged,
              )
            : Text('appointments'.tr(),
                style: TextStyle(fontSize: timeFontSize * 1.5)),
        centerTitle: true,
        backgroundColor: getAppbarColor(context),
        actions: [
          buildSearchBar(),
        ],
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          const SizedBox(height: 22.0),
          buildExpandedField(context, isSearching, searchQuery),
        ],
      ),
      floatingActionButton:
          _isAdmin ? buildCreateAppointmentButton(context) : null,
    );
  }

  PopupMenuItem<int> buildPopupMenuItem(
      BuildContext context, String text, int value, IconData icon) {
    bool isSelected = selectedSortOption == value;

    return PopupMenuItem(
      value: value,
      child: ListTile(
        leading: Icon(icon,
            color: isSelected
                ? getButtonColor(context)
                : getListTileColor(context)),
        title: Text(
          text.tr(),
          style: TextStyle(
            color: isSelected
                ? getButtonColor(context)
                : getListTileColor(context),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        trailing: isSelected
            ? Icon(
                Icons.check,
                color: getButtonColor(context),
                size: 17.0,
              )
            : null,
      ),
    );
  }

  PopupMenuButton<int> buildPopupMenuButton(BuildContext context) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);
    return PopupMenuButton<int>(
      icon: Icon(
        Icons.sort_by_alpha_sharp,
        color: getButtonColor(context),
        size: timeFontSize * 1.8,
      ),
      offset: const Offset(0, 60),
      onSelected: (int result) {
        setState(() {
          selectedSortOption = result;
        });
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<int>>[
        buildPopupMenuItem(context, 'newest', 0, Icons.new_label),
        buildPopupMenuItem(context, 'oldest', 1, Icons.history),
        buildPopupMenuItem(context, 'most_participated', 2, Icons.groups_2),
        buildPopupMenuItem(context, 'least_participated', 3, Icons.group),
        buildPopupMenuItem(context, 'exp_date_asc', 4, Icons.date_range_sharp),
        buildPopupMenuItem(context, 'exp_date_des', 5, Icons.date_range),
      ],
    );
  }

  Widget buildSearchBar() {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);
    return _isSearching
        ? IconButton(
            icon: Icon(
              Icons.close,
              size: timeFontSize * 1.8,
              color: getButtonColor(context),
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
              size: timeFontSize * 1.8,
              color: getButtonColor(context),
            ),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
              });
            },
          );
  }

  Widget buildExpandedField(
      BuildContext context, bool isSearching, String searchQuery) {
    final appointmentListProvider =
        Provider.of<AppointmentDataProvider>(context);
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);

    if (_isLoading) {
      return const Expanded(
        child: Center(child: CustomLoadingWidget(loadingText: 'loading')),
      );
    }

    List<Appointment> filteredAppointments =
        appointmentListProvider.appointments.where((appoinments) {
      final lowerCaseQuery = searchQuery.toLowerCase();
      return appoinments.title.toLowerCase().contains(lowerCaseQuery) ||
          appoinments.appointmentId.toLowerCase().contains(lowerCaseQuery) ||
          format(appoinments.creationDate)
              .toLowerCase()
              .contains(lowerCaseQuery);
    }).toList();
    switch (selectedSortOption) {
      case 0:
        filteredAppointments
            .sort((a, b) => b.creationDate.compareTo(a.creationDate));

        break;
      case 1:
        filteredAppointments
            .sort((a, b) => a.creationDate.compareTo(b.creationDate));
        break;
      case 2:
        filteredAppointments.sort(
            (a, b) => b.participationCount.compareTo(a.participationCount));
        break;
      case 3:
        filteredAppointments.sort(
            (a, b) => a.participationCount.compareTo(b.participationCount));
        break;
      case 4:
        filteredAppointments
            .sort((a, b) => a.expirationDate.compareTo(b.expirationDate));
        break;
      case 5:
        filteredAppointments
            .sort((a, b) => b.expirationDate.compareTo(a.expirationDate));
        break;
    }

    final totalPages =
        (filteredAppointments.length / _appointmentsPerPage).ceil();
    final startIndex = _currentPage * _appointmentsPerPage;
    final endIndex =
        startIndex + _appointmentsPerPage > filteredAppointments.length
            ? filteredAppointments.length
            : startIndex + _appointmentsPerPage;
    final appointmentsForCurrentPage =
        filteredAppointments.sublist(startIndex, endIndex);
    if (filteredAppointments.isEmpty) {
      return Expanded(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              isSearching
                  ? 'search_survey_or_test_not_found'.tr()
                  : 'no_appointments_added_yet'.tr(),
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
                itemCount: appointmentsForCurrentPage.length,
                itemBuilder: (context, index) {
                  final appointment = filteredAppointments[index];
                  bool hasParticipated = appointmentListProvider
                          .userParticipationStatus[appointment.appointmentId] ??
                      false;
                  return AppointmentListItem(
                      appointment: appointmentsForCurrentPage[index],
                      hasUserParticipated: hasParticipated,
                      isAdmin: _isAdmin);
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
