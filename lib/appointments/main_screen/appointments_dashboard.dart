import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:survey_app_ks/appointments/appointment_data.dart';
import 'package:survey_app_ks/appointments/firebase/appointment_services.dart';
import 'package:survey_app_ks/appointments/main_screen/appointment_search_field.dart';
import 'package:survey_app_ks/appointments/main_screen/create_appointment_button.dart';
import 'package:survey_app_ks/appointments/main_screen/appointment_list.dart';
import 'package:survey_app_ks/settings/font_size_provider.dart';
import 'package:survey_app_ks/utilities/colors.dart';
import 'package:survey_app_ks/utilities/tablet_size.dart';

class AppointmentPageUI extends StatefulWidget {
  const AppointmentPageUI({super.key});

  @override
  State<AppointmentPageUI> createState() => AppointmentPageUIState();
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 80);
}

enum SortingOption {
  mostParticipants,
  leastParticipants,
}

class AppointmentPageUIState extends State<AppointmentPageUI> {
  int focusIndex = -1;
  bool isSearching = false;
  String searchQuery = '';
  bool _isAdmin = false;
  int currentPage = 0;

  late AppointmentService _appointmentService;

  @override
  void initState() {
    super.initState();
    _appointmentService = AppointmentService();
    _initPage();
  }

  void _initPage() async {
    final isAdmin = await _appointmentService.fetchAdminStatus();

    if (!mounted) return;

    setState(() {
      _isAdmin = isAdmin;
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
                style: TextStyle(fontSize: timeFontSize + 3)),
        centerTitle: true,
        backgroundColor: ThemeBasedAppColors.getColor(context, 'appbarColor'),
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
                ? ThemeBasedAppColors.getColor(context, 'buttonColor')
                : ThemeBasedAppColors.getColor(context, 'listTileColor')),
        title: Text(
          text.tr(),
          style: TextStyle(
            color: isSelected
                ? ThemeBasedAppColors.getColor(context, 'buttonColor')
                : ThemeBasedAppColors.getColor(context, 'listTileColor'),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        trailing: isSelected
            ? Icon(
                Icons.check,
                color: ThemeBasedAppColors.getColor(context, 'buttonColor'),
                size: 17.0,
              )
            : null,
      ),
    );
  }

  PopupMenuButton<int> buildPopupMenuButton(BuildContext context) {
    return PopupMenuButton<int>(
      icon: Icon(
        Icons.sort_by_alpha_sharp,
        color: ThemeBasedAppColors.getColor(context, 'buttonColor'),
        size: 24.0,
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
              color: ThemeBasedAppColors.getColor(context, 'buttonColor'),
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
              color: ThemeBasedAppColors.getColor(context, 'buttonColor'),
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
    final appointmentService =
        Provider.of<AppointmentService>(context, listen: false);
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);

    const int appointmentsPerPage = 4;

    return FutureBuilder<String?>(
      future: appointmentService.getCompanyId(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const Center(child: CircularProgressIndicator());
        }

        String companyId = snapshot.data!;

        return StreamBuilder<List<Appointment>>(
          stream: appointmentService.getAppointmentList(companyId),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            List<Appointment> appointments = snapshot.data ?? [];
            final filteredAppointments = appointments
                .where((appointment) =>
                    appointment.title
                        .toLowerCase()
                        .contains(searchQuery.toLowerCase()) ||
                    appointment.appointmentId
                        .toLowerCase()
                        .contains(searchQuery.toLowerCase()))
                .toList();

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
                filteredAppointments.sort((a, b) =>
                    b.participationCount.compareTo(a.participationCount));
                break;
              case 3:
                filteredAppointments.sort((a, b) =>
                    a.participationCount.compareTo(b.participationCount));
                break;
              case 4:
                filteredAppointments.sort(
                    (a, b) => a.expirationDate.compareTo(b.expirationDate));
                break;
              case 5:
                filteredAppointments.sort(
                    (a, b) => b.expirationDate.compareTo(a.expirationDate));
                break;
            }

            final int totalPages =
                (filteredAppointments.length / appointmentsPerPage).ceil();

            int start = currentPage * appointmentsPerPage;
            int end = start + appointmentsPerPage;
            end = end > filteredAppointments.length
                ? filteredAppointments.length
                : end;

            final appointmentsForCurrentPage =
                filteredAppointments.sublist(start, end);
            if (filteredAppointments.isEmpty) {
              return Expanded(
                child: Center(
                    child: Text('no_surveys_added_yet'.tr(),
                        style: TextStyle(fontSize: timeFontSize * 1.2))),
              );
            }
            return Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: ListView.separated(
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 20.0),
                      itemCount: appointmentsForCurrentPage.length,
                      itemBuilder: (context, index) {
                        return AppointmentListItem(
                          appointment: appointmentsForCurrentPage[index],
                          hasUserParticipated: false,
                        );
                      },
                    ),
                  ),
                  // Navigation controls
                  if (totalPages > 1)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.chevron_left_outlined,
                            color: currentPage > 0
                                ? ThemeBasedAppColors.getColor(
                                    context, 'buttonColor')
                                : Colors.grey,
                          ),
                          onPressed: currentPage > 0
                              ? () {
                                  setState(() {
                                    currentPage--;
                                  });
                                }
                              : null,
                        ),
                        Text('${currentPage + 1} of $totalPages'),
                        IconButton(
                          icon: Icon(
                            Icons.chevron_right_outlined,
                            color: currentPage < totalPages - 1
                                ? ThemeBasedAppColors.getColor(
                                    context, 'buttonColor')
                                : Colors.grey,
                          ),
                          onPressed: currentPage < totalPages - 1
                              ? () {
                                  setState(() {
                                    currentPage++;
                                  });
                                }
                              : null,
                        ),
                      ],
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
