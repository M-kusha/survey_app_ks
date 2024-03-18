import 'package:easy_localization/easy_localization.dart';
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
  String? _selectedCompanyId;

  void _finishRegistration() async {
    try {
      await widget.registerLogic.registerUser(companyId: _selectedCompanyId);
      if (!context.mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
            builder: (context) => const RegistrationSuccessPage()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Registration failed: $e')));
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
      body: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildSearchBar(),
            const SizedBox(height: 20),
            _buildCompanyList(),
          ],
        ),
      ),
      bottomNavigationBar: _selectedCompanyId != null
          ? buildBottomElevatedButton(
              context: context,
              onPressed: _finishRegistration,
              buttonText: 'finish_registration'.tr(),
            )
          : null,
    );
  }

  Widget _buildSearchBar() => Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'search_company'.tr(),
            prefixIcon: const Icon(Icons.search),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
          ),
          onChanged: (value) => setState(() {}),
        ),
      );

  Widget _buildLoadingIndicator() {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
      ),
      width: 100,
      height: 100,
      child: CircularProgressIndicator(
        valueColor:
            AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
        strokeWidth: 6,
      ),
    );
  }

  Widget _buildCompanyList() => Expanded(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: widget.registerLogic.searchCompanies(_searchController.text),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingIndicator();
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(child: Text('company_not_found'.tr()));
            }
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final company = snapshot.data![index];
                return _buildCompanyTile(company);
              },
            );
          },
        ),
      );

  Widget _buildCompanyTile(Map<String, dynamic> company) => Card(
        elevation: isSelected(company['id']) ? 5 : 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: ListTile(
          leading: const Icon(Icons.business),
          title: Text(company['name']),
          trailing: isSelected(company['id'])
              ? const Icon(
                  Icons.check,
                )
              : null,
          onTap: () => selectCompany(company['id']),
        ),
      );

  bool isSelected(String id) => _selectedCompanyId == id;

  void selectCompany(String id) {
    setState(() => _selectedCompanyId = id);
  }
}
