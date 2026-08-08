import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/settings/font_size_provider.dart';
import 'package:echomeet/utilities/colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class UIUtils {
  /// Shows a transient message.
  ///
  /// Styling comes from the theme's `snackBarTheme` rather than being rebuilt
  /// here. The old version painted *every* message in the error colour, so
  /// "Password updated successfully" arrived in red, and hardcoded a width of
  /// half the screen with padding computed from the other 20% — which wrapped
  /// badly on anything wider than a phone.
  ///
  /// Pass [isError] for genuine failures; they get the error colour, and only
  /// they do.
  static void showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    final scheme = Theme.of(context).colorScheme;

    ScaffoldMessenger.of(context)
      // Queued snackbars used to stack up behind each other; a new message
      // should replace whatever is on screen.
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message.tr()),
          backgroundColor: isError ? scheme.errorContainer : null,
          showCloseIcon: true,
          duration: Duration(seconds: isError ? 5 : 3),
        ),
      );
  }

  static void showLoadingIndicator(
    BuildContext context, {
    String loadingText = "Loading...",
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          backgroundColor: ThemeBasedAppColors.getColor(
            context,
            'snackBarColor',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  ThemeBasedAppColors.getColor(context, 'buttonColor'),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                loadingText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ThemeBasedAppColors.getColor(context, 'textColor'),
                ),
              ),
            ],
          ),
        );
      },
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
          style: ButtonStyle(
            minimumSize: WidgetStateProperty.all(
              Size.fromHeight(defaultButtonHeight),
            ),
            padding: WidgetStateProperty.all(
              EdgeInsets.symmetric(vertical: defaultFontSize * 0.5),
            ),
            backgroundColor: WidgetStateProperty.resolveWith<Color>((
              Set<WidgetState> states,
            ) {
              if (Theme.of(context).brightness == Brightness.light) {
                return Colors.grey[100]!;
              } else {
                return Colors.grey[900]!;
              }
            }),
            foregroundColor: WidgetStateProperty.resolveWith<Color>((
              Set<WidgetState> states,
            ) {
              if (Theme.of(context).brightness == Brightness.light) {
                return Colors.grey[900]!;
              } else {
                return const Color.fromARGB(255, 255, 255, 255);
              }
            }),
            shape: WidgetStateProperty.all<RoundedRectangleBorder>(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(32),
                side: BorderSide(
                  color: ThemeBasedAppColors.getColor(context, 'buttonColor'),
                  width: 1.0,
                ),
              ),
            ),
          ),
          onPressed: onPressed,
          child: Text(
            buttonText.tr(),
            style: TextStyle(fontSize: defaultFontSize),
          ),
        ),
        const SizedBox(height: 16.0),
      ],
    ),
  );
}

class CustomLoadingWidget extends StatelessWidget {
  final double height;
  final String loadingText;

  const CustomLoadingWidget({
    super.key,
    this.height = 160.0,
    this.loadingText = "",
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        height: height,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                ThemeBasedAppColors.getColor(context, 'buttonColor'),
              ),
            ),
            const SizedBox(height: 8.0),
            Text(
              loadingText.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ThemeBasedAppColors.getColor(context, 'buttonColor'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
