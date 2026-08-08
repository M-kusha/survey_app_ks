import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/layout/page_body.dart';
import 'package:echomeet/login/biometrics.dart';
import 'package:echomeet/login/login_logics.dart';
import 'package:echomeet/login/user_preferences.dart';
import 'package:echomeet/utilities/reusable_widgets.dart';
import 'package:echomeet/utilities/settings_controller.dart';
import 'package:echomeet/utilities/text_style.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class LoginPage extends StatefulWidget {
  final AdaptiveThemeMode? savedThemeMode;

  const LoginPage({super.key, this.savedThemeMode});

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
  bool _useBiometricAuthentication = false;

  @override
  void initState() {
    super.initState();
    _useBiometricAuthentication = UserPreferences.getBiometricAuthEnabled();
    SettingsController().getThemeBool().then((value) {
      if (!mounted) return;
      setState(() {
        _light = value;
      });
    });
    _restoreRememberedUser();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Pre-fills the email and greeting only. The password is deliberately never
  /// stored, so "remember me" cannot pre-fill it.
  void _restoreRememberedUser() {
    if (!UserPreferences.getRememberMe()) return;
    setState(() {
      _rememberMe = true;
      _emailController.text = UserPreferences.getEmail() ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoginIn) {
      return const Scaffold(
        body: Center(child: CustomLoadingWidget(loadingText: "login_in")),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: PageBody(
          maxWidth: 460,
          centerVertically: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildWelcomeBack(),
              const SizedBox(height: Spacing.xxl),
              _buildLoginContainer(),
              const SizedBox(height: Spacing.xl),
              _buildSocialLoginButtons(),
              const SizedBox(height: Spacing.lg),
              _buildRegisterLink(),
            ],
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
                style: TextStyle(fontSize: 18, color: getButtonColor(context)),
              ),
            ],
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.calendar_month_outlined,
                size: 35,
                color: getButtonColor(context),
              ),
              const SizedBox(width: 10),
              Text(
                'app_title'.tr(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: getButtonColor(context),
                ),
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
              Text(
                'login_title'.tr(),
                style: Theme.of(context).textTheme.titleLarge,
              ),
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
              icon: Icon(Icons.facebook, color: getButtonColor(context)),
              onPressed: () {},
            ),
            Text('facebook_login'.tr(), style: const TextStyle(fontSize: 12.0)),
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

  /// Unlocks an existing session with biometrics.
  ///
  /// Biometrics re-open a session Firebase is already holding; they are not a
  /// credential and cannot create one. If there is no session left — after a
  /// sign-out, or once Firebase has expired it — the app must fall back to the
  /// password form, otherwise it would navigate to a home screen whose first
  /// `currentUser!` read crashes on null.
  Future<void> _handleLogin() async {
    final authService = AuthService();
    final available =
        await authService.canCheckBiometrics() &&
        await authService.isDeviceSupported();

    final hasSession = FirebaseAuth.instance.currentUser != null;

    if (!available ||
        !UserPreferences.getBiometricAuthEnabled() ||
        !hasSession) {
      if (!mounted) return;
      setState(() => _useBiometricAuthentication = false);
      return;
    }

    if (!await authService.authenticateUser()) {
      if (!mounted) return;
      setState(() => _useBiometricAuthentication = false);
      return;
    }

    _navigateToHome();
  }

  Future<void> _manualLogin() async {
    setState(() {
      isLoginIn = true;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    bool success = await _authManager.signInWithEmailAndPassword(
      email,
      password,
      rememberMe: _rememberMe,
    );

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
