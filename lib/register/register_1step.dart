import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:survey_app_ks/register/register_2step.dart';
import 'package:survey_app_ks/utilities/colors.dart';
import 'package:survey_app_ks/register/register_logics.dart';
import 'package:survey_app_ks/utilities/reusable_widgets.dart';

class Register1step extends StatefulWidget {
  final RegisterLogic registerLogic;

  const Register1step({Key? key, required this.registerLogic})
      : super(key: key);

  @override
  Register1stepState createState() => Register1stepState();
}

class Register1stepState extends State<Register1step> {
  ProfileType? _selectedType;

  void _navigateToNextPage() {
    if (_selectedType != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Register2step(
            registerLogic: widget.registerLogic,
            profileType: _selectedType!,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('register'.tr()),
        centerTitle: true,
        backgroundColor: ThemeBasedAppColors.getColor(context, 'appbarColor'),
      ),
      body: Center(
        child: Card(
          shadowColor: ThemeBasedAppColors.getColor(context, 'buttonColor'),
          margin: const EdgeInsets.all(20),
          elevation: 5,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 40),
              Text(
                'chose_registration_type'.tr(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              UserTypeCard(
                userType: 'register_as_company'.tr(),
                icon: Icons.business,
                color: _selectedType == ProfileType.company
                    ? ThemeBasedAppColors.getColor(context, 'buttonColor')
                    : ThemeBasedAppColors.getColor(context, 'selectedColor'),
                onTap: () =>
                    setState(() => _selectedType = ProfileType.company),
              ),
              UserTypeCard(
                userType: 'register_as_user'.tr(),
                icon: Icons.person,
                color: _selectedType == ProfileType.user
                    ? ThemeBasedAppColors.getColor(context, 'buttonColor')
                    : ThemeBasedAppColors.getColor(context, 'selectedColor'),
                onTap: () => setState(() => _selectedType = ProfileType.user),
              ),
              const SizedBox(height: 40),
              _alreadyHaveAnAccount(),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
      bottomNavigationBar: buildBottomElevatedButton(
        context: context,
        onPressed: _navigateToNextPage,
        buttonText: 'next',
      ),
    );
  }

  Widget _alreadyHaveAnAccount() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('already_have_account'.tr()),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(
            'login_title'.tr(),
          ),
        ),
      ],
    );
  }
}

class UserTypeCard extends StatelessWidget {
  final String userType;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const UserTypeCard(
      {Key? key,
      required this.userType,
      required this.icon,
      required this.onTap,
      required this.color})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color, // Use the color
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: Icon(icon, size: 30),
        title: Text(userType, style: const TextStyle(fontSize: 15)),
        onTap: onTap,
      ),
    );
  }
}
