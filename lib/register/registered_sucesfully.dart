import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/utilities/text_style.dart';
import 'package:flutter/material.dart';

class RegistrationSuccessPage extends StatefulWidget {
  const RegistrationSuccessPage({super.key});

  @override
  RegistrationSuccessPageState createState() => RegistrationSuccessPageState();
}

class RegistrationSuccessPageState extends State<RegistrationSuccessPage> {
  int _counter = 5;
  late Timer _timer;

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_counter > 0) {
        setState(() {
          _counter--;
        });
      } else {
        _timer.cancel();
        Navigator.pushNamedAndRemoveUntil(
            context, '/login', (Route<dynamic> route) => false);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Card(
        elevation: 5,
        shadowColor: getButtonColor(context),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.check_circle_outline,
                  size: 40,
                  color: getButtonColor(context),
                ),
                const SizedBox(height: 30),
                Text(
                  "registration_success".tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ), // Change as needed
                ),
                const SizedBox(height: 20),
                Text(
                  "${tr("you_will_be_redirected")} $_counter ${tr("registration_seconds")}.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(
                        context, '/login', (Route<dynamic> route) => false);
                  },
                  child: Text(
                    tr("back_to_login"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
