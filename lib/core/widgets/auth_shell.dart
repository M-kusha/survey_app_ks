import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/layout/page_body.dart';
import 'package:echomeet/core/theme/app_theme.dart';
import 'package:echomeet/core/widgets/brand_mark.dart';
import 'package:echomeet/core/widgets/aurora_background.dart';
import 'package:echomeet/core/widgets/language_button.dart';
import 'package:echomeet/core/widgets/theme_toggle_button.dart';
import 'package:flutter/material.dart';

class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.headline,
    required this.form,
    this.art,
    this.onBack,
    this.aboveHeadline,
  });

  final Widget headline;

  final Widget? aboveHeadline;

  final Widget form;

  final Widget? art;

  final VoidCallback? onBack;

  static const double _splitAt = 900;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= _splitAt;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AuroraBackground(
        child: SafeArea(
          child: Stack(
            children: [
              if (wide) _buildSplit(context) else _buildStacked(context),
              const Positioned(
                top: Spacing.md,
                right: Spacing.lg,
                child: Row(
                  children: [
                    LanguageButton(),
                    SizedBox(width: Spacing.sm),
                    ThemeToggleButton(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSplit(BuildContext context) {
    final aside = <Widget>[
      _Wordmark(onBack: onBack),
      const Spacer(),
      if (aboveHeadline case final above?) ...[
        above,
        const SizedBox(height: Spacing.lg),
      ],
      headline,
      if (art case final art?) ...[
        const SizedBox(height: Spacing.xxl),
        Expanded(flex: 3, child: art),
      ] else
        const Spacer(),
    ];

    return Row(
      children: [
        Expanded(
          flex: 6,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(64, 48, 40, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: aside,
            ),
          ),
        ),
        Expanded(
          flex: 5,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 48,
                vertical: Spacing.xxl,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: form,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStacked(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return PageBody(
      maxWidth: 460,
      centerVertically: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Wordmark(onBack: onBack),
          const SizedBox(height: Spacing.xxl),
          if (aboveHeadline case final above?) ...[
            above,
            const SizedBox(height: Spacing.lg),
          ],
          headline,
          const SizedBox(height: Spacing.xxl),

          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  scheme.outlineVariant,
                  scheme.outlineVariant.withValues(alpha: 0),
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.xxl),
          form,
        ],
      ),
    );
  }
}

class AuthHeadline extends StatelessWidget {
  const AuthHeadline({super.key, required this.title, required this.subtitle});

  final String title;

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wide = MediaQuery.sizeOf(context).width >= AuthShell._splitAt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.tr(),

          style:
              (wide
                      ? theme.textTheme.displaySmall
                      : theme.textTheme.headlineMedium)
                  ?.copyWith(height: 1.05),
        ),
        const SizedBox(height: Spacing.md),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Text(
            subtitle.tr(),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark({this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onBack case final onBack?) ...[
          _CircleIconButton(icon: Icons.arrow_back_rounded, onTap: onBack),
          const SizedBox(width: Spacing.md),
        ],
        Container(
          height: 34,
          width: 34,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [scheme.primary, scheme.tertiary],
            ),
          ),
          child: Center(child: BrandMark(size: 20, color: scheme.onPrimary)),
        ),
        const SizedBox(width: Spacing.md),
        Text(
          'app_title'.tr(),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontFamily: AppTheme.displayFontFamily,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainerHigh.withValues(alpha: 0.55),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 20, color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
