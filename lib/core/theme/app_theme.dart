import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class AppTheme {
  static const seed = Color(0xFF004B96);

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    final appColors = isDark ? AppColors.dark : AppColors.light;

    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,

      fontFamily: fontFamily,
    );
    final textTheme = _textTheme(base.textTheme, scheme);

    return base.copyWith(
      extensions: [appColors],
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.pageSurface,

      canvasColor: scheme.pageSurface,
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: Spacing.lg,
      ),
      appBarTheme: AppBarTheme(
        // Matches the page so there is no seam where the bar ends.
        backgroundColor: scheme.pageSurface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: scheme.surfaceTint,
        elevation: 0,
        scrolledUnderElevation: 3,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: scheme.cardSurface,
        surfaceTintColor: Colors.transparent,
        elevation: scheme.cardElevation,
        shadowColor: scheme.shadow.withValues(alpha: 0.18),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),

          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 2,
        highlightElevation: 0,
        extendedTextStyle: textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        extendedPadding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
        extendedIconLabelSpacing: Spacing.sm,
        extendedSizeConstraints: const BoxConstraints.tightFor(height: 44),
        shape: const StadiumBorder(),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
          textStyle: textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.full),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
          disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
          textStyle: textTheme.labelLarge,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.full),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
          textStyle: textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.full),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: textTheme.labelLarge,
          minimumSize: const Size(0, 44),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg,
          vertical: Spacing.lg,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        floatingLabelStyle: TextStyle(color: scheme.primary),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        selectedColor: scheme.secondaryContainer,
        labelStyle: textTheme.labelMedium,
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.full),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: textTheme.bodyLarge,
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.secondaryContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelMedium),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.secondaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.onSecondaryContainer),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        selectedItemColor: scheme.primary,
        unselectedItemColor: scheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHighest,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(scheme.onPrimary),
        side: BorderSide(color: scheme.outline, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.xs),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.surfaceContainerHighest,
        thumbColor: scheme.primary,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        textStyle: textTheme.bodySmall?.copyWith(
          color: scheme.onInverseSurface,
        ),
      ),
    );
  }

  static const fontFamily = 'Inter';

  static const displayFontFamily = 'Space Grotesk';

  static TextTheme _textTheme(TextTheme rawBase, ColorScheme scheme) {
    final base = rawBase.apply(
      fontFamily: fontFamily,
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontFamily: displayFontFamily,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.5,
      ),
      displayMedium: base.displayMedium?.copyWith(
        fontFamily: displayFontFamily,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.0,
      ),
      displaySmall: base.displaySmall?.copyWith(
        fontFamily: displayFontFamily,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        fontFamily: displayFontFamily,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontFamily: displayFontFamily,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontFamily: displayFontFamily,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontFamily: displayFontFamily,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: base.bodyLarge?.copyWith(height: 1.4),
      bodyMedium: base.bodyMedium?.copyWith(height: 1.45),
      bodySmall: base.bodySmall?.copyWith(
        height: 1.4,
        color: scheme.onSurfaceVariant,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),

      labelSmall: base.labelSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 1.1,
      ),
    );
  }
}

/// Which tone the page is, and which tone sits on top of it.
///
/// Material 3's light surfaces are all within a few percent of white, so the
/// default arrangement — a card on `surface` — renders #F3F3FA on #F9F9FF, a
/// contrast ratio of 1.05. The card is invisible; only its hairline border
/// suggests anything is there, and a screen of them reads as empty. Light mode
/// therefore tints the page and lifts cards to white, which is the relationship
/// the eye already knows as "card on a page".
///
/// Dark mode keeps Material's direction. There a lighter panel on a darker page
/// already separates, and inverting it would sink cards below the page for no
/// gain.
extension AppSurfaces on ColorScheme {
  bool get _isDark => brightness == Brightness.dark;

  /// Behind everything: scaffolds, app bars, the canvas.
  Color get pageSurface => _isDark ? surface : surfaceContainer;

  /// Cards, sheets and anything meant to read as raised off the page.
  Color get cardSurface =>
      _isDark ? surfaceContainerLow : surfaceContainerLowest;

  /// A card whose content is finished or expired: present, but not competing.
  Color get mutedCardSurface =>
      _isDark ? surfaceContainerLowest : surfaceContainer;

  /// Cards carry a real shadow in light mode. In dark mode a shadow is a
  /// darker smudge on an already dark page, so tone alone does the work.
  double get cardElevation => _isDark ? 0 : 1;
}

abstract final class Radii {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 20;
  static const double full = 999;
}
