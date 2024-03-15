import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:survey_app_ks/utilities/colors.dart';

enum ProfileType { user, company }

class RegisterPage extends StatefulWidget {
  const RegisterPage({Key? key}) : super(key: key);

  @override
  RegisterPageState createState() => RegisterPageState();
}

class RegisterPageState extends State<RegisterPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _fullnameController = TextEditingController();
  final TextEditingController _birthdateController = TextEditingController();
  final TextEditingController _companyNameController = TextEditingController();

  ProfileType _profileType = ProfileType.user;

  File? _profileImage;
  DateTime _selectedDate = DateTime.now();
  bool _showTermsWarning = false;
  bool _acceptTerms = false;
  bool _showFieldsWarning = false;
  String? _selectedCompanyId;

  Future<List<Map<String, dynamic>>> searchCompanies(String query) async {
    final result = await FirebaseFirestore.instance
        .collection('companies')
        .where('name', isGreaterThanOrEqualTo: query)
        .get();

    return result.docs
        .map((doc) => {
              'id': doc.id,
              'name': doc.data()['name'],
            })
        .toList();
  }

  Future<void> _registerUser(
      {String? companyId, bool isCompany = false}) async {
    if (_areFieldsEmpty() || !_acceptTerms) {
      setState(() {
        _showFieldsWarning = true;
      });

      setState(() {
        _showFieldsWarning = false;
      });
      if (!_acceptTerms) {
        setState(() {
          _showTermsWarning = true;
        });
        return;
      }
      setState(() {
        _showTermsWarning = false;
      });
      return;
    }

    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final User user = userCredential.user!;
      final String uid = user.uid;

      Map<String, dynamic> userData = {
        'fullName': _fullnameController.text.trim(),
        'birthdate': _birthdateController.text.trim(),
        'email': _emailController.text.trim(),
        'role': isCompany ? 'admin' : 'user',
        'createdAt': FieldValue.serverTimestamp(),
        if (companyId != null) 'companyId': companyId,
      };

      if (_profileImage != null) {
        String imageUrl = await _uploadProfileImage(uid);
        userData['profileImage'] = imageUrl;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(userData);

      _handleSuccess();
    } catch (e) {
      // Handle errors, e.g., email already in use
    }
  }

  Future<String> _uploadProfileImage(String uid) async {
    final storageRef =
        FirebaseStorage.instance.ref().child('profile_images/$uid');
    final uploadTask = storageRef.putFile(_profileImage!);
    final snapshot = await uploadTask.whenComplete(() => null);
    return await snapshot.ref.getDownloadURL();
  }

  Future<void> _registerCompany() async {
    DocumentReference companyDoc =
        FirebaseFirestore.instance.collection('companies').doc();

    await companyDoc.set({
      'name': _companyNameController.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    _registerUser(companyId: companyDoc.id, isCompany: true);
  }

  Widget _profileTypeSelection() {
    return Row(
      children: [
        ElevatedButton(
          onPressed: () => setState(() => _profileType = ProfileType.user),
          style: ElevatedButton.styleFrom(
              foregroundColor: _profileType == ProfileType.user
                  ? ThemeBasedAppColors.getColor(context, 'textColor')
                  : ThemeData.light().inputDecorationTheme.fillColor,
              backgroundColor: _profileType == ProfileType.user
                  ? ThemeBasedAppColors.getColor(context, 'buttonColor')
                  : ThemeData.light().inputDecorationTheme.fillColor),
          child: Text('register_as_user'.tr()),
        ),
        ElevatedButton(
          onPressed: () => setState(() => _profileType = ProfileType.company),
          style: ElevatedButton.styleFrom(
              foregroundColor: _profileType == ProfileType.company
                  ? ThemeBasedAppColors.getColor(context, 'textColor')
                  : ThemeData.light().inputDecorationTheme.fillColor,
              backgroundColor: _profileType == ProfileType.company
                  ? ThemeBasedAppColors.getColor(context, 'buttonColor')
                  : ThemeData.light().inputDecorationTheme.fillColor),
          child: Text('register_as_company'.tr()),
        ),
      ],
    );
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedImage =
        await picker.pickImage(source: ImageSource.gallery);

    if (pickedImage != null) {
      setState(() {
        _profileImage = File(pickedImage.path);
      });
    }
  }

  bool _areFieldsEmpty() {
    List<TextEditingController> controllers = [
      _emailController,
      _passwordController,
      _confirmPasswordController,
      _fullnameController,
      _birthdateController,
    ];

    return controllers.any((controller) => controller.text.isEmpty);
  }

  Future<void> _selectBirthdate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate = pickedDate;
        _birthdateController.text =
            DateFormat('d MMMM yyyy').format(pickedDate);
      });
    }
  }

  void _handleSuccess() {
    Navigator.of(context)
        .pop(); // Change this to navigate to your success screen
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullnameController.dispose();
    _birthdateController.dispose();
    super.dispose();
  }

  Widget _profileImageSection() {
    return GestureDetector(
      onTap: _pickImage,
      child: CircleAvatar(
        radius: 50,
        backgroundColor: _profileImage == null
            ? ThemeBasedAppColors.getColor(context, 'buttonColor')
            : ThemeData.light().inputDecorationTheme.fillColor,
        backgroundImage:
            _profileImage != null ? FileImage(_profileImage!) : null,
        child: _profileImage == null
            ? Icon(Icons.add_a_photo,
                size: 40,
                color: ThemeBasedAppColors.getColor(context, 'textColor'))
            : null,
      ),
    );
  }

  Widget _formFieldSection() {
    List<Widget> fields = [
      _buildTextField(
          _fullnameController, 'fullname'.tr(), false, TextInputType.text),
      _buildTextField(
          _emailController, 'email'.tr(), false, TextInputType.emailAddress),
      _buildTextField(_passwordController, 'password'.tr(), true,
          TextInputType.visiblePassword),
      _buildTextField(_confirmPasswordController, 'confirm_password'.tr(), true,
          TextInputType.visiblePassword),
      _buildDateField('birthdate'.tr(), _birthdateController),
      _pleaseFillAllTheFields(),
    ];

    if (_profileType == ProfileType.user) {
      fields.add(_buildCompanySelector());
    } else if (_profileType == ProfileType.company) {
      fields.add(_buildTextField(_companyNameController, 'company_name'.tr(),
          false, TextInputType.text));
    }

    fields.add(_pleaseFillAllTheFields()); // Include any warnings
    return Column(children: fields);
  }

  Widget _registerButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        foregroundColor: ThemeBasedAppColors.getColor(context, 'textColor'),
        backgroundColor: ThemeBasedAppColors.getColor(context, 'buttonColor'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30.0),
        ),
        minimumSize: const Size.fromHeight(50),
      ),
      onPressed: () {
        if (_profileType == ProfileType.company) {
          _registerCompany();
        } else {
          // Pass the selected company ID for a user
          _registerUser(companyId: _selectedCompanyId);
        }
      },
      child: Text(
        'register'.tr(),
      ),
    );
  }

  Widget _buildCompanySelector() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: searchCompanies(''),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }

        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }

        return Column(
          children: [
            DropdownButtonFormField<String>(
              items: snapshot.data!
                  .map((company) => DropdownMenuItem<String>(
                        value: company['id'],
                        child: Text(company['name']),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCompanyId = value;
                });
              },
              value: _selectedCompanyId,
              decoration: InputDecoration(
                labelText: 'company'.tr(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: ThemeData.light().inputDecorationTheme.fillColor,
              ),
            ),
            _pleaseFillAllTheFields(),
          ],
        );
      },
    );
  }

  Widget _alreadyHaveAnAccount() {
    return Row(
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

  Widget _buildAcceptTerms() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: _acceptTerms,
          onChanged: (value) {
            setState(() {
              _acceptTerms = value!;
              _showTermsWarning = false;
            });
          },
        ),
        Text('i_agree_to_the'.tr()),
        TextButton(
          onPressed: () {
            // Navigate to terms and conditions page
          },
          child: Text(
            'terms_and_conditions'.tr(),
            style: TextStyle(
              color: _showTermsWarning ? Colors.red : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _pleaseFillAllTheFields() {
    return Visibility(
      visible: _showFieldsWarning,
      child: Text(
        'please_fill_all_fields'.tr(),
        style: const TextStyle(color: Colors.red, fontSize: 12),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      bool isObscure, TextInputType keyboardType) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        obscureText: isObscure,
        keyboardType: keyboardType,
        decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: ThemeData.light().inputDecorationTheme.fillColor),
      ),
    );
  }

  Widget _buildDateField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: GestureDetector(
        onTap: _selectBirthdate,
        child: AbsorbPointer(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixIcon: const Icon(Icons.calendar_today),
              filled: true,
              fillColor: ThemeData.light().inputDecorationTheme.fillColor,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                const SizedBox(height: 30),
                _profileImageSection(),
                const SizedBox(height: 30),
                _profileTypeSelection(),
                const SizedBox(height: 20),
                _formFieldSection(),
                const SizedBox(height: 20),
                _registerButton(),
                const SizedBox(height: 10),
                Center(child: _buildAcceptTerms()),
                _alreadyHaveAnAccount(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
