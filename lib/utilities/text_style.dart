import 'package:echomeet/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Shared colour accessors.
///
/// These are called from 47 of the 49 UI files, which is why they are the seam
/// the redesign went through: re-pointing them at the Material 3 `ColorScheme`
/// restyled the whole app without editing every screen.
///
/// They previously read from a hand-written `Map<String, Color>` where a
/// mistyped key silently returned blue, and whose *light* theme set
/// `textColor: white` and `cardColor: grey[800]` — the reason foreground and
/// background colours disagreed in places.
///
/// New code should prefer `Theme.of(context).colorScheme` and
/// `context.appColors` directly. These remain so existing screens keep working
/// and stay themable.

ColorScheme _scheme(BuildContext context) => Theme.of(context).colorScheme;

/// Primary action colour — buttons, active icons, selected states.
Color getButtonColor(BuildContext context) => _scheme(context).primary;

/// Foreground for content sitting *on* [getButtonColor].
///
/// Named "text colour", but it has always been used as the on-primary pair
/// rather than as body-text colour. Body text should come from the text theme.
Color getTextColor(BuildContext context) => _scheme(context).onPrimary;

/// Text and icons on ordinary list rows.
Color getListTileColor(BuildContext context) => _scheme(context).onSurface;

/// App bars sit flush with the page in Material 3 and lift only on scroll.
Color getAppbarColor(BuildContext context) => _scheme(context).surface;

/// Secondary icons — the camera badge on an avatar, trailing chevrons.
Color getCameraColor(BuildContext context) => _scheme(context).onSurfaceVariant;

Color getIconColor(BuildContext context) => _scheme(context).onSurfaceVariant;

/// Card surfaces. Slightly raised from the page rather than a fixed grey, so
/// cards stay legible in both themes.
Color getCardColor(BuildContext context) =>
    _scheme(context).surfaceContainerLow;

/// Attendance and review states, from the semantic palette.
Color getSuccessColor(BuildContext context) => context.appColors.success;
Color getWarningColor(BuildContext context) => context.appColors.warning;
Color getParticipatedColor(BuildContext context) =>
    context.appColors.participated;
Color getNotParticipatedColor(BuildContext context) =>
    context.appColors.notParticipated;

// ---------------------------------------------------------------------------
// Legacy shared widgets.
//
// Kept so existing screens compile, but they no longer hardcode colours — the
// icon theme used to be a fixed dark red regardless of theme, and the text
// style a fixed black45 that vanished on a dark background.
// ---------------------------------------------------------------------------

const Divider dividerSettings = Divider(height: 20);
const SizedBox sizedBoxSettings = SizedBox(height: 10);
const SizedBox sizedBoxSettingsSmall = SizedBox(height: 6);
const SizedBox sizeSettingsLarge = SizedBox(height: 40);

TextStyle appTextStyle(BuildContext context) =>
    Theme.of(context).textTheme.bodyMedium ?? const TextStyle();

IconThemeData appIconTheme(BuildContext context) =>
    IconThemeData(color: _scheme(context).onSurfaceVariant, size: 24);
