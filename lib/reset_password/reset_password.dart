import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/widgets/app_text_field.dart';
import 'package:echomeet/core/widgets/auth_shell.dart';
import 'package:echomeet/core/widgets/glass_panel.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isSending = false;
  bool _linkSent = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSending = true;
      _error = null;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _linkSent = true);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      setState(() {
        if (e.code == 'invalid-email') {
          _error = 'invalid_email_message'.tr();
        } else {
          _linkSent = true;
        }
      });
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      onBack: () => Navigator.of(context).maybePop(),

      headline: const AuthHeadline(
        title: 'reset_headline',
        subtitle: 'reset_subhead',
      ),
      form: GlassPanel(
        padding: const EdgeInsets.all(Spacing.xl),

        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
          child: _linkSent ? _buildConfirmation() : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return KeyedSubtree(
      key: const ValueKey('form'),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              label: 'email'.tr(),
              controller: _emailController,
              icon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _sendResetLink(),
              validator: (value) {
                if (_error != null) return _error;
                return (value == null || value.trim().isEmpty)
                    ? 'invalid_email_message'.tr()
                    : null;
              },
            ),
            const SizedBox(height: Spacing.xl),
            GlowButton(
              onPressed: _sendResetLink,
              busy: _isSending,
              label: 'send_reset_link'.tr(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmation() {
    final scheme = Theme.of(context).colorScheme;
    final app = Theme.of(context);
    return Column(
      key: const ValueKey('sent'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Halo(
          icon: Icons.mark_email_read_rounded,
          colors: [scheme.tertiary, scheme.primary],
        ),
        const SizedBox(height: Spacing.xl),
        Text(
          'reset_link_sent'.tr(),
          textAlign: TextAlign.center,
          style: app.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: Spacing.sm),
        Text(
          'reset_link_sent_body'.tr(
            namedArgs: {'email': _emailController.text.trim()},
          ),
          textAlign: TextAlign.center,
          style: app.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Spacing.xl),
        GlowButton(
          onPressed: () => Navigator.of(context).pop(),
          label: 'back_to_login'.tr(),
        ),
      ],
    );
  }
}

class _Halo extends StatelessWidget {
  const _Halo({required this.icon, required this.colors});

  final IconData icon;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        height: 64,
        width: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.first.withValues(alpha: 0.45),
              blurRadius: 26,
              spreadRadius: -4,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 30,
          color: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
    );
  }
}
