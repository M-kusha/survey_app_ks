import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/settings/font_size_provider.dart';
import 'package:echomeet/utilities/colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

  static void showLoadingIndicator(BuildContext context,
      {String loadingText = "Loading..."}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          backgroundColor:
              ThemeBasedAppColors.getColor(context, 'snackBarColor'),
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
            minimumSize:
                MaterialStateProperty.all(Size.fromHeight(defaultButtonHeight)),
            padding: MaterialStateProperty.all(
                EdgeInsets.symmetric(vertical: defaultFontSize * 0.5)),
            backgroundColor: MaterialStateProperty.resolveWith<Color>(
                (Set<MaterialState> states) {
              if (Theme.of(context).brightness == Brightness.light) {
                return Colors.grey[100]!;
              } else {
                return Colors.grey[900]!;
              }
            }),
            foregroundColor: MaterialStateProperty.resolveWith<Color>(
                (Set<MaterialState> states) {
              if (Theme.of(context).brightness == Brightness.light) {
                return Colors.grey[900]!;
              } else {
                return const Color.fromARGB(255, 255, 255, 255);
              }
            }),
            shape: MaterialStateProperty.all<RoundedRectangleBorder>(
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
    Key? key,
    this.height = 160.0,
    this.loadingText = "",
  }) : super(key: key);

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
