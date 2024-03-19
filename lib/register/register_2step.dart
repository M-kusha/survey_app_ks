import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:survey_app_ks/register/register_3step.dart';
import 'package:survey_app_ks/utilities/colors.dart';
import 'package:survey_app_ks/register/register_logics.dart';
import 'package:survey_app_ks/utilities/reusable_widgets.dart';

class Register2step extends StatefulWidget {
  final RegisterLogic registerLogic;
  final ProfileType profileType;

  const Register2step(
      {Key? key, required this.registerLogic, required this.profileType})
      : super(key: key);

  @override
  State<Register2step> createState() => _Register2stepState();
}

class _Register2stepState extends State<Register2step> {
  late final TextEditingController _fullnameController =
      widget.registerLogic.fullnameController;
  late final TextEditingController _birthdateController =
      widget.registerLogic.birthdateController;
  late final TextEditingController _emailController =
      widget.registerLogic.emailController;
  late final _companyNameController =
      widget.registerLogic.companyNameController;

  bool _areFieldsValid() {
    bool isValid = _fullnameController.text.isNotEmpty &&
        _birthdateController.text.isNotEmpty &&
        _emailController.text.isNotEmpty;

    if (widget.profileType == ProfileType.company) {
      isValid =
          isValid && widget.registerLogic.companyNameController.text.isNotEmpty;
    }

    return isValid;
  }

  bool _validateEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+',
    );
    return emailRegex.hasMatch(email);
  }

  void _onNextPressed() async {
    if (!_areFieldsValid()) {
      UIUtils.showSnackBar(context, 'please_fill_all_fields'.tr());
      return;
    }

    if (!_validateEmail(_emailController.text)) {
      UIUtils.showSnackBar(context, 'invalid_email_message'.tr());

      return;
    }

    String? companyId;
    if (widget.profileType == ProfileType.company) {
      companyId = await widget.registerLogic.registerCompany();
    }
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Register3step(
          registerLogic: widget.registerLogic,
          profileType: widget.profileType,
          companyId: companyId,
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedImage =
        await picker.pickImage(source: ImageSource.gallery);

    if (pickedImage != null) {
      setState(() {
        widget.registerLogic.setProfileImage(File(pickedImage.path));
      });
    }
  }

  Widget _profileImageSection() {
    return GestureDetector(
      onTap: _pickImage,
      child: CircleAvatar(
        radius: 50,
        backgroundColor: ThemeBasedAppColors.getColor(context, 'buttonColor'),
        backgroundImage: widget.registerLogic.profileImage != null
            ? FileImage(widget.registerLogic.profileImage!) as ImageProvider
            : null,
        child: widget.registerLogic.profileImage == null
            ? Icon(Icons.camera_alt,
                size: 40,
                color: ThemeBasedAppColors.getColor(context, 'textColor'))
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('basic_information'.tr()),
        centerTitle: true,
        backgroundColor: ThemeBasedAppColors.getColor(context, 'appbarColor'),
      ),
      body: Center(
        child: Card(
          shadowColor: ThemeBasedAppColors.getColor(context, 'buttonColor'),
          margin: const EdgeInsets.all(20),
          elevation: 5,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 30),
                _profileImageSection(),
                const SizedBox(height: 30),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextFormField(
                    controller: _fullnameController,
                    decoration: InputDecoration(
                      labelText: 'fullname'.tr(),
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      prefixIcon: Icon(Icons.person,
                          color: ThemeBasedAppColors.getColor(
                              context, 'buttonColor')),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextFormField(
                    controller: _birthdateController,
                    decoration: InputDecoration(
                      labelText: 'birthdate'.tr(),
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      prefixIcon: Icon(Icons.calendar_today,
                          color: ThemeBasedAppColors.getColor(
                              context, 'buttonColor')),
                    ),
                    onTap: () {
                      final DateTime currentDate = DateTime.now();
                      final DateTime minDate = DateTime(currentDate.year - 18,
                          currentDate.month, currentDate.day);
                      showDatePicker(
                        context: context,
                        initialDate: minDate,
                        firstDate: DateTime(1900),
                        lastDate: minDate,
                      ).then((value) {
                        if (value != null) {
                          _birthdateController.text =
                              DateFormat('d MMMM yyyy').format(value);
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(height: 5),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'email'.tr(),
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      prefixIcon: Icon(Icons.email,
                          color: ThemeBasedAppColors.getColor(
                              context, 'buttonColor')),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                if (widget.profileType == ProfileType.company)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextFormField(
                      controller: _companyNameController,
                      decoration: InputDecoration(
                        labelText: 'company_name'.tr(),
                        prefixIcon: Icon(Icons.business,
                            color: ThemeBasedAppColors.getColor(
                                context, 'buttonColor')),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: buildBottomElevatedButton(
        context: context,
        onPressed: _onNextPressed,
        buttonText: 'next',
      ),
    );
  }
}
