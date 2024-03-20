import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:survey_app_ks/utilities/colors.dart';
import 'package:survey_app_ks/utilities/settings_controller.dart';

class LoginPage extends StatefulWidget {
  final AdaptiveThemeMode? savedThemeMode;
  final String message;
  const LoginPage({Key? key, required this.message, this.savedThemeMode})
      : super(key: key);

  @override
  LoginPageState createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  String _errorMessage = '';
  bool _passwordVisible = false;
  bool _light = true;

  @override
  void initState() {
    super.initState();
    SettingsController().getThemeBool().then((value) {
      setState(() {
        _light = value;
      });
    });
    _loadRememberMe();
  }

  _loadRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    bool rememberMe = prefs.getBool('rememberMe') ?? false;
    setState(() {
      _rememberMe = rememberMe;
      if (rememberMe) {
        _emailController.text = prefs.getString('email') ?? '';
        _passwordController.text = prefs.getString('password') ?? '';
      }
    });
  }

  _saveRememberMe(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('rememberMe', value);
    if (value) {
      prefs.setString('email', _emailController.text.trim());
      prefs.setString('password', _passwordController.text.trim());
    } else {
      prefs.remove('email');
      prefs.remove('password');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const SizedBox(height: 60),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      size: 35,
                      color:
                          ThemeBasedAppColors.getColor(context, 'buttonColor'),
                    ),
                    // ignore: prefer_const_constructors
                    SizedBox(width: 10),
                    Text(
                      'app_title'.tr(),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: ThemeBasedAppColors.getColor(
                            context, 'buttonColor'),
                        fontFamily: 'CustomFont', // Use your custom font
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 50),
                _buildLoginContainer(),
                const SizedBox(height: 20),
                _buildSocialLoginButtons(),
                const SizedBox(height: 20),
                _buildRegisterLink(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildThemeSwitch() {
    return IconButtonTheme(
      data: const IconButtonThemeData(),
      child: IconButton(
        icon: _light ? const Icon(Icons.sunny) : const Icon(Icons.brightness_3),
        onPressed: () {
          setState(() {
            _light = !_light;
            if (_light) {
              AdaptiveTheme.of(context).setDark();
            } else {
              AdaptiveTheme.of(context).setLight();
            }
            SettingsController().saveThemeBool(_light);
          });
        },
      ),
    );
  }

  Widget _buildLoginContainer() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: AdaptiveTheme.of(context).theme.scaffoldBackgroundColor,
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('login_title'.tr(),
                  style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              buildThemeSwitch(),
            ],
          ),
          const SizedBox(height: 20),
          _buildEmailField(),
          const SizedBox(height: 20),
          _buildPasswordField(),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Checkbox(
                    checkColor:
                        ThemeBasedAppColors.getColor(context, 'textColor'),
                    activeColor:
                        ThemeBasedAppColors.getColor(context, 'buttonColor'),
                    value: _rememberMe,
                    onChanged: (value) {
                      setState(() {
                        _rememberMe = value!;
                      });
                    },
                  ),
                  Text(
                    'remember_me'.tr(),
                    style: const TextStyle(
                      fontSize: 12.0, // Specify your desired font size here
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/reset_password'),
                  child: const Text("forgot_password").tr(),
                ),
              ),
            ],
          ),
          _buildErrorMessage(),
          const SizedBox(height: 20),
          _buildLoginButton(),
        ],
      ),
    );
  }

  Widget _buildEmailField() {
    return TextField(
      controller: _emailController,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        labelText: tr("email_label"),
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: _passwordController,
      obscureText: !_passwordVisible,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        labelText: tr("password_label"),
        suffixIcon: IconButton(
          icon: Icon(
            _passwordVisible ? Icons.visibility : Icons.visibility_off,
          ),
          onPressed: () {
            setState(() {
              _passwordVisible = !_passwordVisible;
            });
          },
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    if (_errorMessage.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          _errorMessage,
          style: const TextStyle(color: Colors.red, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      );
    }
    return Container();
  }

  Widget _buildLoginButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        foregroundColor: ThemeBasedAppColors.getColor(context, 'textColor'),
        backgroundColor: ThemeBasedAppColors.getColor(context, 'buttonColor'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30.0),
        ),
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16.0),
      ),
      onPressed: _handleLogin,
      child: const Text('login_button').tr(),
    );
  }

  Widget _buildSocialLoginButtons() {
    return Column(
      children: [
        const Divider(),
        const SizedBox(height: 20),
        const Text('or_login_with').tr(),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(Icons.g_mobiledata,
                  color: ThemeBasedAppColors.getColor(context, 'buttonColor')),
              onPressed: () {
                // Handle Google login
              },
            ),
            const Text('google_login').tr(),
            const SizedBox(width: 20),
            IconButton(
              icon: Icon(
                Icons.facebook,
                color: ThemeBasedAppColors.getColor(context, 'buttonColor'),
              ),
              onPressed: () {},
            ),
            Text(
              'facebook_login'.tr(),
              style: const TextStyle(
                fontSize: 12.0,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("dont_have_account").tr(),
        TextButton(
          onPressed: () => Navigator.pushNamed(context, '/register'),
          child: const Text('create_new_account').tr(),
        ),
      ],
    );
  }

  Future<void> _handleLogin() async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      _saveRememberMe(_rememberMe);
      _handleLoginSuccess();
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'An unknown error occurred';
      });
    }
  }

  void _handleLoginSuccess() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      String? companyId = userData['companyId'];
      String? role = userData['role'];

      final prefs = await SharedPreferences.getInstance();
      if (companyId != null) {
        prefs.setString('companyId', companyId);
      }
      if (role != null) {
        prefs.setString('userRole', role);
      }

      if (!context.mounted) return;

      Navigator.pushReplacementNamed(context, '/home');
    }
  }
}
