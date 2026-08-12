import 'dart:async';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/theme/app_theme.dart';
import 'package:echomeet/core/navigation/public_routes.dart';
import 'package:echomeet/core/notifications/push_service.dart';
import 'package:echomeet/core/notifications/notification_navigation.dart';
import 'package:echomeet/core/widgets/app_text_field.dart';
import 'package:echomeet/core/widgets/auth_shell.dart';
import 'package:echomeet/core/widgets/glass_panel.dart';
import 'package:echomeet/core/widgets/product_showcase.dart';
import 'package:echomeet/login/biometrics.dart';
import 'package:echomeet/login/login_logics.dart';
import 'package:echomeet/login/session_access.dart';
import 'package:echomeet/login/user_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
  final _formKey = GlobalKey<FormState>();

  bool _isSigningIn = false;
  bool _rememberMe = false;
  String? _errorMessage;
  bool _passwordVisible = false;
  bool _useBiometricAuthentication = false;

  @override
  void initState() {
    super.initState();
    _restoreRememberedUser();
    _resolveBiometricOffer();
  }

  Future<void> _resolveBiometricOffer() async {
    if (!UserPreferences.getBiometricAuthEnabled() ||
        FirebaseAuth.instance.currentUser == null) {
      return;
    }

    final service = AuthService();
    final usable =
        await service.canCheckBiometrics() && await service.isDeviceSupported();
    if (!mounted || !usable) return;

    setState(() => _useBiometricAuthentication = true);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _restoreRememberedUser() {
    if (!UserPreferences.getRememberMe()) return;
    setState(() {
      _rememberMe = true;
      _emailController.text = UserPreferences.getEmail() ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      headline: const AuthHeadline(
        title: 'login_headline',
        subtitle: 'login_subhead',
      ),
      art: const ProductShowcase(),
      form: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFormIntro(),
          const SizedBox(height: Spacing.lg),
          _buildCard(),
          const SizedBox(height: Spacing.lg),
          _buildRegisterLink(),
          const PublicLegalLinks(),
        ],
      ),
    );
  }

  Widget _buildFormIntro() {
    final name = UserPreferences.getFullName();
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name == null ? 'login_title'.tr() : 'welcome_back'.tr(),
          style: theme.textTheme.titleLarge,
        ),
        if (name != null) ...[
          const SizedBox(height: Spacing.xs),
          Text(
            name,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCard() {
    return GlassPanel(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildEmailField(),
            const SizedBox(height: Spacing.lg),
            _buildPasswordField(),
            const SizedBox(height: Spacing.sm),
            _buildMetaRow(),
            if (_errorMessage != null) ...[
              const SizedBox(height: Spacing.md),
              _buildError(),
            ],
            const SizedBox(height: Spacing.lg),
            GlowButton(
              onPressed: _useBiometricAuthentication
                  ? _handleLogin
                  : _manualLogin,
              busy: _isSigningIn,
              label: _useBiometricAuthentication
                  ? 'biometrics'.tr()
                  : 'login_button'.tr(),
              icon: _useBiometricAuthentication ? Icons.fingerprint : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return AppTextField(
      label: tr('email_label'),
      controller: _emailController,
      icon: Icons.alternate_email_rounded,
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.username, AutofillHints.email],
      textInputAction: TextInputAction.next,
      validator: (value) => (value == null || value.trim().isEmpty)
          ? 'invalid_email_message'.tr()
          : null,
    );
  }

  Widget _buildPasswordField() {
    return AppTextField(
      label: tr('password_label'),
      controller: _passwordController,
      icon: Icons.lock_outline_rounded,
      obscure: !_passwordVisible,
      autofillHints: const [AutofillHints.password],
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _manualLogin(),
      validator: (value) =>
          (value == null || value.isEmpty) ? 'password_empty'.tr() : null,
      trailing: IconButton(
        icon: Icon(
          _passwordVisible
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          size: 19,
        ),
        onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
      ),
    );
  }

  Widget _buildMetaRow() {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => setState(() => _rememberMe = !_rememberMe),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    height: 22,
                    width: 22,
                    child: Checkbox(
                      value: _rememberMe,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (value) =>
                          setState(() => _rememberMe = value ?? false),
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Flexible(
                    child: Text(
                      'remember_me'.tr(),
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: scheme.onSurface),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pushNamed(context, '/reset_password'),
          child: Text('forgot_password'.tr()),
        ),
      ],
    );
  }

  Widget _buildError() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: scheme.onErrorContainer,
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(
              _errorMessage!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterLink() {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'dont_have_account'.tr(),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        TextButton(
          onPressed: () => Navigator.pushNamed(context, '/register'),
          child: Text('create_new_account'.tr()),
        ),
      ],
    );
  }

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
    if (_isSigningIn) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSigningIn = true;
      _errorMessage = null;
    });

    final success = await _authManager.signInWithEmailAndPassword(
      _emailController.text.trim(),
      _passwordController.text.trim(),
      rememberMe: _rememberMe,
    );

    if (!mounted) return;

    if (success) {
      _navigateToHome();
      return;
    }

    setState(() {
      _errorMessage = switch (_authManager.lastFailure) {
        SignInFailure.emailNotVerified => 'email_not_verified'.tr(),
        SignInFailure.sessionCleanupFailed => 'error_occurred'.tr(),
        _ => 'login_failed'.tr(),
      };
      _isSigningIn = false;
    });
  }

  void _navigateToHome() {
    if (!mounted) return;
    context.read<SessionAccess>().unlock();
    unawaited(PushService().startIfEnabled());
    Navigator.pushReplacementNamed(context, '/home');
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => NotificationNavigation.appReady(),
    );
  }
}

/// Signed-out links to the two public legal and account-data resources.
/// The two pages that have to be reachable without an account.
///
/// These were full-size `TextButton`s in a `Wrap`, so on a narrow screen they
/// stacked into two tall blocks that read as primary actions competing with
/// signing in. They are references, not things anybody came here to do, so they
/// now sit on one quiet line. The tap target stays finger-sized; only the ink
/// is smaller.
class PublicLegalLinks extends StatelessWidget {
  const PublicLegalLinks({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
      decoration: TextDecoration.underline,
      decorationColor: scheme.onSurfaceVariant.withValues(alpha: 0.4),
    );

    Widget link(String labelKey, String route) => InkWell(
      onTap: () => Navigator.pushNamed(context, route),
      borderRadius: BorderRadius.circular(Radii.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm,
          vertical: Spacing.md,
        ),
        child: Text(labelKey.tr(), style: style),
      ),
    );

    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          link('privacy_policy_link', PublicRoutePaths.privacyPolicy),
          Text('·', style: style?.copyWith(decoration: TextDecoration.none)),
          link('account_deletion_info_link', PublicRoutePaths.accountDeletion),
        ],
      ),
    );
  }
}
