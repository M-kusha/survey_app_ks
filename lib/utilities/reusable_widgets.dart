import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:survey_app_ks/settings/font_size_provider.dart';
import 'package:survey_app_ks/utilities/colors.dart';

class UIUtils {
  static void showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.5,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              message.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: ThemeBasedAppColors.getColor(context, 'errorColor')),
            ),
          ),
        ),
        backgroundColor: ThemeBasedAppColors.getColor(context, 'snackBarColor'),
        padding: EdgeInsets.symmetric(
          horizontal: (MediaQuery.of(context).size.width -
                  (MediaQuery.of(context).size.width * 0.8)) /
              2,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
      ),
    );
  }
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
