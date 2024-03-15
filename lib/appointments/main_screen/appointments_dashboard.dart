import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:survey_app_ks/appointments/appointment_data.dart';
import 'package:survey_app_ks/appointments/firebase/appointment_services.dart';
import 'package:survey_app_ks/appointments/main_screen/appointment_search_field.dart';
import 'package:survey_app_ks/appointments/main_screen/create_appointment_button.dart';
import 'package:survey_app_ks/appointments/main_screen/appointment_list.dart';
import 'package:survey_app_ks/settings/font_size_provider.dart';
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
  late List<Appointment> appointmentList;
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
        leading: buildPopupMenuButton(context), // PopupMenuButton on the left
        title: _isSearching
            ? ActionField(
                isSearching: _isSearching,
                searchController: searchController,
                onSearchTextChanged: _onSearchTextChanged,
              )
            : Text('appointments'.tr(),
                style: TextStyle(fontSize: timeFontSize + 3)),
        centerTitle: true,
        actions: [
          buildSearchBar(), // Search bar on the right
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
              appointmentList.sort((a, b) =>
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
              appointmentList.sort((a, b) =>
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
              appointmentList
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
              appointmentList
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
