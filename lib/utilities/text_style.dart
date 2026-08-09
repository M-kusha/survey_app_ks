import 'package:echomeet/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

ColorScheme _scheme(BuildContext context) => Theme.of(context).colorScheme;

Color getButtonColor(BuildContext context) => _scheme(context).primary;

Color getTextColor(BuildContext context) => _scheme(context).onPrimary;

Color getListTileColor(BuildContext context) => _scheme(context).onSurface;

Color getAppbarColor(BuildContext context) => _scheme(context).surface;

Color getCameraColor(BuildContext context) => _scheme(context).onSurfaceVariant;

Color getIconColor(BuildContext context) => _scheme(context).onSurfaceVariant;

Color getCardColor(BuildContext context) =>
    _scheme(context).surfaceContainerLow;

Color getSuccessColor(BuildContext context) => context.appColors.success;
Color getWarningColor(BuildContext context) => context.appColors.warning;
Color getParticipatedColor(BuildContext context) =>
    context.appColors.participated;
Color getNotParticipatedColor(BuildContext context) =>
    context.appColors.notParticipated;

const Divider dividerSettings = Divider(height: 20);
const SizedBox sizedBoxSettings = SizedBox(height: 10);
const SizedBox sizedBoxSettingsSmall = SizedBox(height: 6);
const SizedBox sizeSettingsLarge = SizedBox(height: 40);

TextStyle appTextStyle(BuildContext context) =>
    Theme.of(context).textTheme.bodyMedium ?? const TextStyle();

IconThemeData appIconTheme(BuildContext context) =>
    IconThemeData(color: _scheme(context).onSurfaceVariant, size: 24);
