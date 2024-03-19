import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:survey_app_ks/register/registered_sucesfully.dart';
import 'package:survey_app_ks/utilities/colors.dart';
import 'package:survey_app_ks/register/register_logics.dart';
import 'package:survey_app_ks/utilities/reusable_widgets.dart';

class Register4step extends StatefulWidget {
  final RegisterLogic registerLogic;

  const Register4step({Key? key, required this.registerLogic})
      : super(key: key);

  @override
  Register4stepState createState() => Register4stepState();
}

class Register4stepState extends State<Register4step> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allCompanies = [];
  List<Map<String, dynamic>> _filteredCompanies = [];
  String? _selectedCompanyId;
  bool _isSaving = false;
  bool _isLoading = true;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _fetchCompanies();
    _searchController.addListener(_filterCompanies);
  }

  void _fetchCompanies() async {
    final companies = await widget.registerLogic.searchCompanies('');
    if (!mounted) return;
    setState(() {
      _allCompanies = companies;
      _filteredCompanies = companies;
      _isLoading = false;
    });
  }

  void _filterCompanies() {
    final query = _searchController.text.toLowerCase();
    final filtered = _allCompanies.where((company) {
      final nameLower = company['name'].toLowerCase();
      return nameLower.contains(query);
    }).toList();

    setState(() => _filteredCompanies = filtered);
  }

  void _finishRegistration() async {
    setState(() {
      _isSaving = true;
    });

    try {
      await widget.registerLogic.registerUser(companyId: _selectedCompanyId);
      if (!context.mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
            builder: (context) => const RegistrationSuccessPage()),
        (Route<dynamic> route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        UIUtils.showSnackBar(context, 'email_already_exists'.tr());
      } else {
        UIUtils.showSnackBar(context, 'Registration failed: ${e.message}');
      }
    } catch (e) {
      UIUtils.showSnackBar(context, 'An unexpected error occurred.');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(
            'select_company'.tr(),
          ),
          centerTitle: true,
          backgroundColor:
              ThemeBasedAppColors.getColor(context, 'appbarColor')),
      body: _isSaving
          ? const Center(
              child: CustomLoadingWidget(
              loadingText: 'saving_regisration',
            ))
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    _buildCompanyList(),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: _selectedCompanyId != null && !_isSaving
          ? buildBottomElevatedButton(
              context: context,
              onPressed: _finishRegistration,
              buttonText: 'finish_registration'.tr(),
            )
          : null,
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        child: _isSearching
            ? Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'search_company'.tr(),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 20),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: ThemeBasedAppColors.getColor(
                                context, 'buttonColor'),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(32),
                        ),
                      ),
                      onChanged: (value) => setState(() {}),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _isSearching = false;
                      });
                    },
                    icon: const Icon(Icons.close),
                  ),
                ],
              )
            : InkWell(
                onTap: () {
                  setState(() {
                    _isSearching = true;
                  });
                },
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Icon(Icons.search, color: Colors.grey),
                ),
              ),
      ),
    );
  }

  Widget _buildCompanyList() {
    final itemCount = _filteredCompanies.length;
    final columnCount = (itemCount / 15).ceil();

    return Expanded(
      child: _isLoading
          ? const CustomLoadingWidget(
              loadingText: 'loading',
            )
          : ListView.builder(
              itemCount: columnCount,
              itemBuilder: (context, columnIndex) {
                final start = columnIndex * 15;
                final end = (columnIndex + 1) * 15;
                final companies = _filteredCompanies.sublist(
                    start, end > itemCount ? itemCount : end);

                return Column(
                  children: [
                    _buildSearchBar(),
                    const SizedBox(height: 20),
                    Card(
                      elevation: 5,
                      margin: const EdgeInsets.all(20),
                      shadowColor:
                          ThemeBasedAppColors.getColor(context, 'buttonColor'),
                      child: Column(
                        children: companies
                            .map((company) => _buildCompanyTile(company))
                            .toList(),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildCompanyTile(Map<String, dynamic> company) => Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Card(
              elevation: isSelected(company['id']) ? 5 : 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: isSelected(company['id'])
                      ? ThemeBasedAppColors.getColor(context, 'buttonColor')
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ListTile(
                leading: Icon(
                  Icons.business,
                  color: ThemeBasedAppColors.getColor(context, 'buttonColor'),
                ),
                title: Text(company['name']),
                trailing: isSelected(company['id'])
                    ? Icon(
                        Icons.check,
                        color: ThemeBasedAppColors.getColor(
                            context, 'buttonColor'),
                      )
                    : null,
                onTap: () => selectCompany(company['id']),
              ),
            ),
          ],
        ),
      );

  bool isSelected(String id) => _selectedCompanyId == id;

  void selectCompany(String id) {
    setState(() => _selectedCompanyId = id);
  }
}
