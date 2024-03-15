import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:survey_app_ks/settings/font_size_provider.dart';

void showCustomSnackBar(BuildContext context, String message,
    {Color? backgroundColor, double? fontSize}) {
  final ThemeData theme = Theme.of(context);
  final Color defaultBackgroundColor = theme.brightness == Brightness.light
      ? const Color(0xff004B96)
      : Colors.white;
  final double defaultFontSize = fontSize ?? 16.0;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message.tr(),
        style: TextStyle(
          fontSize: defaultFontSize,
          fontWeight: FontWeight.bold,
          color: theme.brightness == Brightness.light
              ? Colors.white
              : Colors.black, // Adjust text color based on theme
        ),
        textAlign: TextAlign.center,
      ),
      backgroundColor: backgroundColor ?? defaultBackgroundColor,
    ),
  );
}

Widget buildBottomElevatedButton({
  required BuildContext context,
  required VoidCallback onPressed,
  required String buttonText,
  double? buttonFontSize,
  double? buttonHeight,
}) {
  final double defaultFontSize =
      buttonFontSize ?? Provider.of<FontSizeProvider>(context).fontSize;
  final double defaultButtonHeight = buttonHeight ?? defaultFontSize * 4.0;

  return Padding(
    padding: const EdgeInsets.all(16.0),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              minimumSize: Size.fromHeight(defaultButtonHeight),
              padding: EdgeInsets.symmetric(vertical: defaultFontSize * 0.5),
              foregroundColor: Theme.of(context).brightness == Brightness.light
                  ? Colors.grey[900]
                  : const Color.fromARGB(255, 255, 255, 255),
              backgroundColor: Theme.of(context).brightness == Brightness.light
                  ? Colors.grey[100]
                  : Colors.grey[900]),
          onPressed: onPressed,
          child: Text(
            buttonText
                .tr(), // Assuming you are using easy_localization for i18n
            style: TextStyle(fontSize: defaultFontSize),
          ),
        ),
        const SizedBox(height: 16.0),
      ],
    ),
  );
}
