import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:survey_app_ks/firebase_options.dart';
import 'package:survey_app_ks/settings/font_size_provider.dart';
import 'package:survey_app_ks/utilities/routes.dart';
import 'package:survey_app_ks/login/login.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // final ntfy = NtfyInterface();
  // ntfy.getMessageStream(['Intranet']).then((Stream<MessageResponse> stream) {
  //   stream.listen((MessageResponse message) {
  //     SettingsController().showNotification(message.title, message.message);
  //   });
  // });

  await EasyLocalization.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<FontSizeProvider>(
          create: (context) => FontSizeProvider(),
        ),
      ],
      child: EasyLocalization(
        supportedLocales: const [
          Locale('en', ''),
          Locale('de', ''),
        ],
        path: 'assets/translations',
        fallbackLocale: const Locale('en', ''),
        saveLocale: true,
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  final AdaptiveThemeMode? savedThemeMode;
  const MyApp({super.key, this.savedThemeMode});

  @override
  Widget build(BuildContext context) {
    return AdaptiveTheme(
      light: ThemeData(
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF004B96),
          secondary: Colors.grey,
        ),
      ),
      dark: ThemeData(
        colorScheme: const ColorScheme.dark(
          primary: Colors.grey,
          secondary: Colors.grey,
        ),
      ),
      initial: AdaptiveThemeMode.light,
      builder: (theme, darkTheme) => MaterialApp(
        routes: AppRoutes.routes(),
        locale: context.locale,
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        debugShowCheckedModeBanner: false,
        theme: theme,
        darkTheme: darkTheme,
        home: const LoginPage(
          message: '',
        ),
      ),
    );
    // return MaterialApp(
    //   title: 'Flutter Demo',
    //   locale: context.locale,
    //   localizationsDelegates: context.localizationDelegates,
    //   supportedLocales: context.supportedLocales,
    //   theme: ThemeData(
    //     primarySwatch: Colors.blue,
    //   ),
    //   routes: AppRoutes.routes(),
    //   home: const LoginPage(
    //     message: '',
    //   ),
    //   debugShowCheckedModeBanner: false,
    // );
  }
}
