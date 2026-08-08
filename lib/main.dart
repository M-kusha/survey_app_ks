import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/theme/app_theme.dart';
import 'package:echomeet/appointments/firebase/appointment_provider.dart';
import 'package:echomeet/appointments/firebase/appointment_services.dart';
import 'package:echomeet/firebase_options.dart';
import 'package:echomeet/login/login.dart';
import 'package:echomeet/login/user_preferences.dart';
import 'package:echomeet/register/register_logics.dart';
import 'package:echomeet/settings/font_size_provider.dart';
import 'package:echomeet/survey_pages/utilities/survey_data_provider.dart';
import 'package:echomeet/utilities/firebase_services.dart';
import 'package:echomeet/utilities/routes.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await UserPreferences.init();

  await EasyLocalization.ensureInitialized();

  // Read the stored light/dark choice before the first frame, so the app does
  // not paint in the wrong theme and then flip.
  final savedThemeMode = await AdaptiveTheme.getThemeMode();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<FontSizeProvider>(
          create: (context) => FontSizeProvider(),
        ),
        Provider<AppointmentService>(create: (_) => AppointmentService()),
        Provider<FirebaseServices>(create: (_) => FirebaseServices()),
        Provider<RegisterLogic>(create: (_) => RegisterLogic()),
        ChangeNotifierProvider(create: (context) => SurveyDataProvider()),
        ChangeNotifierProvider(create: (context) => AppointmentDataProvider()),
        ChangeNotifierProvider(
          create: (_) => UserDataProvider()..loadCurrentUser(),
        ),
      ],
      child: EasyLocalization(
        supportedLocales: const [
          Locale('en', ''),
          Locale('de', ''),
          Locale('sq', ''),
        ],
        path: 'assets/translations',
        fallbackLocale: const Locale('en', ''),
        saveLocale: true,
        child: MyApp(savedThemeMode: savedThemeMode),
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
      light: AppTheme.light,
      dark: AppTheme.dark,
      // Restores the mode the user last chose. This previously hardcoded
      // `light`, and `savedThemeMode` was declared but never read — so the app
      // reset to light on every launch no matter what the settings toggle said.
      initial: savedThemeMode ?? AdaptiveThemeMode.system,
      builder: (theme, darkTheme) => MaterialApp(
        routes: AppRoutes.routes(),
        locale: context.locale,
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        debugShowCheckedModeBanner: false,
        theme: theme,
        darkTheme: darkTheme,
        home: const LoginPage(),
      ),
    );
  }
}
