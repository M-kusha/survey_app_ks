import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:survey_app_ks/login/biometrics.dart';
import 'package:survey_app_ks/login/login_logics.dart';
import 'package:survey_app_ks/login/user_preferences.dart';
import 'package:survey_app_ks/utilities/reusable_widgets.dart';
import 'package:survey_app_ks/utilities/settings_controller.dart';
import 'package:survey_app_ks/utilities/text_style.dart';

class LoginPage extends StatefulWidget {
  final AdaptiveThemeMode? savedThemeMode;

  const LoginPage({Key? key, this.savedThemeMode}) : super(key: key);

  @override
  LoginPageState createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> {
  final AuthManager _authManager = AuthManager();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool isLoginIn = false;
  bool _rememberMe = false;
  String _errorMessage = '';
  bool _passwordVisible = false;
  bool _light = true;
  String _fullName = '';
  bool _useBiometricAuthentication = false;

  @override
  void initState() {
    super.initState();
    _useBiometricAuthentication =
        UserPreferences.getBiometricAuthEnabled() ?? false;
    SettingsController().getThemeBool().then((value) {
      setState(() {
        _light = value;
      });
    });
    _loadRememberMe();
  }

  void _loadRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    bool rememberMe = prefs.getBool('rememberMe') ?? false;
    setState(() {
      _rememberMe = rememberMe;
      if (rememberMe) {
        _emailController.text = UserPreferences.getEmail() ?? '';
        _passwordController.text = UserPreferences.getPassword() ?? '';
        _fullName = UserPreferences.getFullName() ?? '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoginIn) {
      return const Scaffold(
        body: Center(
            child: CustomLoadingWidget(
          loadingText: "login_in",
        )),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const SizedBox(height: 60),
                _buildWelcomeBack(),
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

  Widget _buildWelcomeBack() {
    String? fullName = UserPreferences.getFullName();
    return fullName != null
        ? Column(
            children: [
              Text(
                'welcome_back'.tr(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: getButtonColor(context),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                fullName,
                style: TextStyle(
                  fontSize: 18,
                  color: getButtonColor(context),
                ),
              ),
            ],
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.calendar_month_outlined,
                  size: 35, color: getButtonColor(context)),
              const SizedBox(width: 10),
              Text(
                'app_title'.tr(),
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: getButtonColor(context)),
              ),
            ],
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
                    checkColor: getTextColor(context),
                    activeColor: getButtonColor(context),
                    value: _rememberMe,
                    onChanged: (value) {
                      setState(() {
                        _rememberMe = value!;
                      });
                    },
                  ),
                  Text(
                    'remember_me'.tr(),
                    style: const TextStyle(fontSize: 12.0),
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
        foregroundColor: getTextColor(context),
        backgroundColor: getButtonColor(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30.0),
        ),
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16.0),
      ),
      onPressed: () {
        if (_useBiometricAuthentication) {
          _handleLogin();
        } else {
          _manualLogin();
        }
      },
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
              icon: Icon(Icons.g_mobiledata, color: getButtonColor(context)),
              onPressed: () {
                // Handle Google login
              },
            ),
            const Text('google_login').tr(),
            const SizedBox(width: 20),
            IconButton(
              icon: Icon(
                Icons.facebook,
                color: getButtonColor(context),
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
    final canUseBiometric = await AuthService().canCheckBiometrics() &&
        await AuthService().isDeviceSupported();
    final biometricEnabled = UserPreferences.getBiometricAuthEnabled() ?? false;

    if (canUseBiometric && biometricEnabled) {
      bool authenticated = await AuthService().authenticateUser();
      if (authenticated) {
        _navigateToHome();
        return;
      } else {
        setState(() {
          _useBiometricAuthentication = false;
        });
        return;
      }
    } else {
      setState(() {
        _useBiometricAuthentication = false;
      });
    }
  }

  Future<void> _manualLogin() async {
    setState(() {
      isLoginIn = true;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    bool success = await _authManager.signInWithEmailAndPassword(
        email, password, _rememberMe, _fullName);

    if (success) {
      if (!context.mounted) return;
      _navigateToHome();
    } else {
      setState(() {
        _errorMessage = 'login_failed'.tr();
        isLoginIn = false;
      });
    }
  }

  void _navigateToHome() {
    if (!context.mounted) return;
    Navigator.pushReplacementNamed(context, '/home');
  }
}
