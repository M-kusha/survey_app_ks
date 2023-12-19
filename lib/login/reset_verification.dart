import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ResetPasswordVerificationPage extends StatefulWidget {
  const ResetPasswordVerificationPage({super.key});

  @override
  ResetPasswordVerificationPageState createState() =>
      ResetPasswordVerificationPageState();
}

class ResetPasswordVerificationPageState
    extends State<ResetPasswordVerificationPage> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  Timer? clipboardCheckTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => checkClipboard());
    clipboardCheckTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      checkClipboard();
    });
  }

  Future<void> checkClipboard() async {
    ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    String clipboardContent = data?.text?.trim() ?? '';
    if (clipboardContent.length == 6 &&
        RegExp(r'^\d{6}$').hasMatch(clipboardContent)) {
      for (int i = 0; i < clipboardContent.length; i++) {
        _controllers[i].text = clipboardContent[i];
      }
      clipboardCheckTimer?.cancel();
    }
  }

  Future<void> _verifyCodeAndResetPassword() async {
    // final verificationCode =
    //     _controllers.map((controller) => controller.text).join();
    // Implement your verification logic here
    Navigator.pushNamed(context, '/ChangePasswordPage');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('reset_verification'.tr()),
        backgroundColor: Colors.blueGrey,
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 4.0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    const SizedBox(height: 32.0),
                    Text(
                      'enter_reset_code'.tr(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 32.0),
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(
                              6, (index) => buildCodeInput(index, context)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24.0),
                    ElevatedButton(
                      onPressed: _verifyCodeAndResetPassword,
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.blueGrey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30.0),
                        ),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            vertical: 16.0, horizontal: 35.0),
                      ),
                      child: const Text('verify_reset_code').tr(),
                    ),
                    const SizedBox(height: 32.0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildCodeInput(int index, BuildContext context) {
    return SizedBox(
      width: 40,
      height: 60,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        decoration: InputDecoration(
          counterText: "",
          border: OutlineInputBorder(
            borderSide: const BorderSide(width: 2, color: Colors.blueGrey),
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide:
                const BorderSide(width: 2, color: Colors.lightBlueAccent),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onChanged: (value) {
          if (value.length == 1) {
            if (index + 1 < _focusNodes.length) {
              FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
            } else {
              FocusScope.of(context).unfocus();
              _verifyCodeAndResetPassword();
            }
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    clipboardCheckTimer?.cancel();
    super.dispose();
  }
}
