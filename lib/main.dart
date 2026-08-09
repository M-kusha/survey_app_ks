import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/localization/app_locales.dart';
import 'package:echomeet/core/membership/membership.dart';
import 'package:echomeet/core/notifications/notification_navigation.dart';
import 'package:echomeet/core/notifications/notification_locale_service.dart';
import 'package:echomeet/core/notifications/push_service.dart';
import 'package:echomeet/core/security/app_check_bootstrap.dart';
import 'package:echomeet/core/theme/app_theme.dart';
import 'package:echomeet/appointments/firebase/appointment_provider.dart';
import 'package:echomeet/appointments/firebase/appointment_services.dart';
import 'package:echomeet/firebase_options.dart';
import 'package:echomeet/login/login.dart';
import 'package:echomeet/login/session_access.dart';
import 'package:echomeet/login/user_preferences.dart';
import 'package:echomeet/register/register_logics.dart';
import 'package:echomeet/register/deferred_onboarding.dart';
import 'package:echomeet/settings/font_size_provider.dart';
import 'package:echomeet/survey_pages/utilities/survey_data_provider.dart';
import 'package:echomeet/utilities/bottom_navigation.dart';
import 'package:echomeet/utilities/firebase_services.dart';
import 'package:echomeet/utilities/routes.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AppCheckBootstrap.activate();
  await UserPreferences.init();

  await EasyLocalization.ensureInitialized();

  await initializeDateFormatting();

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
        ChangeNotifierProvider(create: (_) => MembershipProvider()),
        ChangeNotifierProvider(create: (_) => SessionAccess()),
        ChangeNotifierProvider(
          create: (_) => UserDataProvider()..loadCurrentUser(),
        ),
      ],
      child: EasyLocalization(
        supportedLocales: AppLocales.supported,
        path: AppLocales.path,
        fallbackLocale: AppLocales.fallback,
        saveLocale: true,
        child: MyApp(savedThemeMode: savedThemeMode),
      ),
    ),
  );
  PushService().observeAuthentication();
}

class MyApp extends StatelessWidget {
  final AdaptiveThemeMode? savedThemeMode;
  const MyApp({super.key, this.savedThemeMode});

  @override
  Widget build(BuildContext context) {
    Intl.defaultLocale = context.locale.toLanguageTag();
    NotificationLocaleService.observe(context.locale);

    return AdaptiveTheme(
      light: AppTheme.light,
      dark: AppTheme.dark,

      initial: savedThemeMode ?? AdaptiveThemeMode.system,
      builder: (theme, darkTheme) => MaterialApp(
        navigatorKey: NotificationNavigation.navigatorKey,
        routes: AppRoutes.routes(),
        locale: context.locale,
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        debugShowCheckedModeBanner: false,
        theme: theme,
        darkTheme: darkTheme,

        builder: (context, child) {
          final media = MediaQuery.of(context);
          final systemScale = media.textScaler.scale(1);
          final preferredScale = context.watch<FontSizeProvider>().textScale;

          return MediaQuery(
            data: media.copyWith(
              textScaler: TextScaler.linear(
                (systemScale * preferredScale).clamp(0.8, 3.0),
              ),
            ),
            child: child!,
          );
        },
        home: const _SessionLanding(),
      ),
    );
  }
}

class _SessionLanding extends StatelessWidget {
  const _SessionLanding();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        final unlocked = context.watch<SessionAccess>().isUnlocked;
        return snapshot.data?.emailVerified == true && unlocked
            ? const DeferredOnboardingGate(child: BottomNavigation())
            : const LoginPage();
      },
    );
  }
}
