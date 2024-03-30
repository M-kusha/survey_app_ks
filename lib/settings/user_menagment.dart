import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/appointments/main_screen/appointment_search_field.dart';
import 'package:echomeet/settings/font_size_provider.dart';
import 'package:echomeet/survey_pages/utilities/firebase_survey_service.dart';
import 'package:echomeet/survey_pages/utilities/survey_data_provider.dart';
import 'package:echomeet/utilities/reusable_widgets.dart';
import 'package:echomeet/utilities/tablet_size.dart';
import 'package:echomeet/utilities/text_style.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class UserManagementPage extends StatefulWidget {
  final String userId;
  const UserManagementPage({Key? key, required this.userId}) : super(key: key);

  @override
  UserManagementPageState createState() => UserManagementPageState();
}

class UserManagementPageState extends State<UserManagementPage> {
  List<UserModel> userList = [];
  String searchQuery = '';
  FirebaseSurveyService firebaseSurveyService = FirebaseSurveyService();
  int currentPage = 1;
  int itemsPerPage = 10;
  bool isLoading = false;
  bool isSearching = false;
  void _onSearchTextChanged(String text) async {
    setState(() {
      searchQuery = text;
    });
  }

  TextEditingController searchController = TextEditingController();

  final Map<String, String> roleLabelsToValues = {
    'Admin': 'admin',
    'Moderator': 'moderator',
    'User': 'user',
  };

  @override
  void initState() {
    super.initState();

    loadUsers();
  }

  void loadUsers() async {
    setState(() {
      isLoading = true;
    });

    String? companyId = await firebaseSurveyService.fetchCurrentUserCompanyId();
    String finalCompanyId = companyId ?? 'defaultCompanyId';

    QuerySnapshot querySnapshot =
        await firebaseSurveyService.fetchUsersByCompanyId(finalCompanyId);

    if (mounted) {
      setState(() {
        userList = querySnapshot.docs
            .map((doc) => UserModel.fromFirestore(doc))
            .toList();
        isLoading = false;
      });
    }
  }

  String capitalize(String input) {
    if (input.isEmpty) return "";
    return input[0].toUpperCase() + input.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);
    List<UserModel> filteredUsers =
        filterUsers(userList, searchQuery, currentPage, itemsPerPage);
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CustomLoadingWidget()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: isSearching
            ? ActionField(
                isSearching: isSearching,
                searchController: searchController,
                onSearchTextChanged: _onSearchTextChanged,
              )
            : Text('user_management'.tr(),
                style: TextStyle(fontSize: timeFontSize * 1.5)),
        backgroundColor: getAppbarColor(context),
        actions: [
          buildSearchBar(
            getButtonColor(context),
          )
        ],
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: buildUserList(filteredUsers),
      ),
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

  Widget buildUserList(List<UserModel> users) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;

    if (users.isEmpty) {
      return Center(
          child: Text('user_list_empty'.tr(),
              style: TextStyle(fontSize: fontSize)));
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              '${'total_users'.tr()} ${users.length}',
              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: users.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) => Card(
                elevation: 5,
                shadowColor: getButtonColor(context),
                child: buildUserItem(users[index], fontSize),
              ),
            ),
          ),
          buildPaginationControls(),
        ],
      ),
    );
  }

  ListTile buildUserItem(UserModel user, double fontSize) {
    return ListTile(
      leading: GestureDetector(
        onTap: () {
          // userProfile(context, user.id);
        },
        child: CircleAvatar(
          backgroundImage: user.profileImage.isNotEmpty
              ? NetworkImage(user.profileImage)
              : null,
          backgroundColor: getIconColor(context),
          child: user.profileImage.isEmpty
              ? Text(user.name[0],
                  style: TextStyle(
                    fontSize: fontSize,
                  ))
              : null,
        ),
      ),
      title: Text(user.name),
      trailing: buildUserRoleSelection(user),
    );
  }

  Widget buildUserRoleSelection(UserModel user) {
    if (user.id == widget.userId) {
      return Text(
        capitalize(user.role),
        style: TextStyle(color: getListTileColor(context), fontSize: 16),
        textAlign: TextAlign.center,
      );
    }

    String currentRoleLabel = roleLabelsToValues.entries
        .firstWhere((entry) => entry.value == user.role,
            orElse: () => roleLabelsToValues.entries.first)
        .key;

    return GestureDetector(
      onTap: () => _showRoleSelectionModal(context, user),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 8,
        ),
        child: Text(
          currentRoleLabel,
          style: const TextStyle(fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  void _showRoleSelectionModal(BuildContext context, UserModel user) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: roleLabelsToValues.entries.map((entry) {
              return ListTile(
                title: Text(entry.key, textAlign: TextAlign.center),
                onTap: () {
                  setState(() {
                    updateUserRole(user.id, entry.value);
                  });
                  Navigator.of(context).pop();
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void updateUserRole(String userId, String newRole) {
    firebaseSurveyService.updateUserRole(userId, newRole).then((_) {
      int userIndex = userList.indexWhere((user) => user.id == userId);
      if (userIndex != -1) {
        setState(() {
          userList[userIndex].role = newRole;
        });
      }
    });
  }

  Widget buildPaginationControls() {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: currentPage > 1 ? () => setState(() => currentPage--) : null,
      ),
      Text('${'page'.tr()} $currentPage'),
      IconButton(
        icon: const Icon(Icons.arrow_forward),
        onPressed: userList.length == itemsPerPage
            ? () => setState(() => currentPage++)
            : null,
      ),
    ]);
  }

  List<UserModel> filterUsers(
      List<UserModel> users, String query, int page, int itemsCount) {
    return users
        .where((user) => user.name.toLowerCase().contains(query.toLowerCase()))
        .skip((page - 1) * itemsCount)
        .take(itemsCount)
        .toList();
  }
}
