import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:survey_app_ks/settings/settings.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final List<Map> deletedListItems = [];

class SettingsController {
  Future<double> getFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('font_size') ?? fontMediumSize;
  }

  Future<void> saveFontSize(double size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('font_size', size);
  }

  void saveThemeBool(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLight', value);
  }

  Future<bool> getThemeBool() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLight') ?? false;
  }

  void saveSortInt(int value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selectedSortOption', value);
  }

  Future<int> getSortInt() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt('selectedSortOption') ?? 0;
  }

  Future saveDeletedItems() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> deletedItems = [];
    for (final item in deletedListItems) {
      deletedItems.add(jsonEncode(item));
    }
    prefs.setStringList('deletedItems', deletedItems);
  }

  void sortItemsAZ(List<Map<Object, dynamic>> workPlaces) {
    for (final workPlace in workPlaces) {
      workPlace['items'].sort((a, b) => a['title'].compareTo(b['title']));
    }
  }

  void sortItemsZA(List<Map<Object, dynamic>> workPlaces) {
    for (final workPlace in workPlaces) {
      workPlace['items'].sort((a, b) => b['title'].compareTo(a['title']));
    }
  }

  /////////////////////////////////// Notifications ///////////////////////////////////

  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  Future<void> showNotification(String? title, String? message) async {
    if (title == null || message == null) {
      return;
    }

    AndroidNotificationDetails androidDetails =
        const AndroidNotificationDetails(
      'Intranet',
      'Main Channel',
      importance: Importance.max,
      priority: Priority.max,
      enableLights: true,
      color: Colors.red,
      colorized: true,
      styleInformation: DefaultStyleInformation(true, true),
    );
    NotificationDetails platformChannelDetails =
        NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      message,
      platformChannelDetails,
    );
  }

  Future<void> initNotification(BuildContext context) async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  // static Future<void> saveMessages(List<NotificationPage> messageList) async {
  //   final prefs = await SharedPreferences.getInstance();
  //   final messageListJson = json.encode(messageList
  //       .map((message) => {
  //             'title': message.title,
  //             'message': message.message,
  //             'time': message.time.toIso8601String(),
  //           })
  //       .toList());
  //   await prefs.setString('messageList', messageListJson);
  // }

  // static Future<List<NotificationPage>> loadMessages() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   final messageListJson = prefs.getString('messageList');
  //   if (messageListJson != null) {
  //     final messageListData = json.decode(messageListJson);
  //     final messageList = messageListData
  //         .map<NotificationPage>((messageData) => NotificationPage(
  //               title: messageData['title'],
  //               message: messageData['message'],
  //               time: DateTime.parse(messageData['time']),
  //               key: UniqueKey(),
  //             ))
  //         .toList();
  //     return messageList;
  //   }
  //   return [];
  // }

  static Future<void> savePriority(String priority) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('priority', priority);
  }

  static Future<String?> loadPriority() async {
    final prefs = await SharedPreferences.getInstance();
    final priority = prefs.getString('priority');
    return priority;
  }

  static Future<void> saveTitle(String topic) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('topic', topic);
  }

  static Future<String?> loadTitle() async {
    final prefs = await SharedPreferences.getInstance();
    final topic = prefs.getString('topic');
    return topic;
  }

  //////////////////////////// OTP ////////////////////////////

  // Future<void> scanQRCodeAndSaveSecretKey(
  //     {VoidCallback? qrCodeScannedCallback}) async {
  //   try {
  //     await storage.deleteAll();
  //     final qrCode = await FlutterBarcodeScanner.scanBarcode(
  //         '#ff6666', 'Cancel', true, ScanMode.QR);

  //     final secretKey = parseSecretKeyFromQRCode(qrCode);
  //     await storage.write(key: 'authenticator_secret', value: secretKey);
  //     await storage.write(
  //         key: 'authenticator_username',
  //         value: 'my_username'); // Add this line to save a username
  //     if (qrCodeScannedCallback != null) {
  //       qrCodeScannedCallback();
  //     }
  //   } catch (e) {
  //     // Handle the error
  //   }
  // }

  // Future<void> deleteSecretKey() async {
  //   try {
  //     const storage = FlutterSecureStorage();
  //     await storage.delete(key: 'authenticator_secret');
  //   } catch (e) {
  //     // Handle the error
  //   }
  // }

  // final storage = const FlutterSecureStorage();
  // final _otpController = StreamController<String>.broadcast();
  // Stream<String> get otpStream => _otpController.stream;

  // String parseSecretKeyFromQRCode(String qrCode) {
  //   // Parse the secret key from the QR code
  //   final uri = Uri.parse(qrCode);
  //   final secretKey = uri.queryParameters['secret'];
  //   if (secretKey == null) {
  //     throw PlatformException(
  //         code: 'INVALID_QR_CODE',
  //         message: 'The QR code is invalid or does not contain a secret key.');
  //   }
  //   return secretKey;
  // }

  // Future<String> getAuthenticatorCredentials() async {
  //   final username = await storage.read(key: 'authenticator_username');
  //   final secret = await storage.read(key: 'authenticator_secret');
  //   if (username != null && secret != null) {
  //     return '$username,$secret';
  //   } else {
  //     throw PlatformException(
  //         code: 'AUTH_NOT_FOUND',
  //         message: 'Authenticator credentials not found.');
  //   }
  // }

  // String generateOTP(String secret) {
  //   // Generate the OTP using the same settings as Google Authenticator
  //   final otp = OTP.generateTOTPCodeString(
  //     secret,
  //     DateTime.now().millisecondsSinceEpoch,
  //     algorithm: Algorithm.SHA1, // Use SHA1 algorithm
  //     length: 6, // Use 6-digit code
  //     interval: 30, // Use 30-second interval
  //     // Use the same number of digits as Google Authenticator (default is 8)
  //     // and don't add spaces between the digits
  //     isGoogle: true,
  //   );
  //   return otp;
  // }

  // Future<void> generateOTPFromQR() async {
  //   try {
  //     final credentials = await getAuthenticatorCredentials();
  //     final secret = credentials.split(',')[1];
  //     final otp = generateOTP(secret);
  //     _otpController.sink.add(otp); // Emit the OTP data to the stream
  //   } catch (e) {
  //     // Handle the error
  //   }
  // }

  // void autofillAuthenticatorOTP(TextEditingController emailController) async {
  //   try {
  //     final credentials = await getAuthenticatorCredentials();
  //     final secret = credentials.split(',')[1];
  //     final otp = generateOTP(secret);
  //     _otpController.sink.add(
  //         otp); // Emit the OTP data to the stream to autofill the OTP field
  //   } catch (e) {
  //     // Handle the error
  //   }
  // }
}
