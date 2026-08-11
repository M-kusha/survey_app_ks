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
import 'package:flutter_quill/flutter_quill.dart' show FlutterQuillLocalizations;
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  late final AdaptiveThemeMode? savedThemeMode;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await AppCheckBootstrap.activate();
    await UserPreferences.init();
    await EasyLocalization.ensureInitialized();
    await initializeDateFormatting();
    savedThemeMode = await AdaptiveTheme.getThemeMode();
  } catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'EchoMeet startup',
      ),
    );
    runApp(const _StartupFailureApp());
    return;
  }

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

/// The note editor's own translations, falling back to English.
///
/// flutter_quill ships no Albanian, and its delegate answers `isSupported`
/// honestly - so on `sq` the framework skips it, every toolbar button asks for
/// an instance that was never loaded, and the editor screen dies. Claiming
/// support for everything and loading English for the gaps costs a few
/// untranslated tooltips instead of the whole screen.
class _QuillLocalizations
    extends LocalizationsDelegate<FlutterQuillLocalizations> {
  const _QuillLocalizations();

  static const _fallback = Locale('en');

  LocalizationsDelegate<FlutterQuillLocalizations> get _inner =>
      FlutterQuillLocalizations.delegate;

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<FlutterQuillLocalizations> load(Locale locale) =>
      _inner.load(_inner.isSupported(locale) ? locale : _fallback);

  @override
  bool shouldReload(_QuillLocalizations old) => false;
}

class _StartupFailureApp extends StatelessWidget {
  const _StartupFailureApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'EchoMeet could not start because its release configuration '
                'is incomplete. Please contact support.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
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
        // The note editor's toolbar reads its own tooltips from a delegate the
        // package ships separately. Without it every toolbar button throws
        // while building, which takes the whole editor screen down.
        localizationsDelegates: [
          ...context.localizationDelegates,
          const _QuillLocalizations(),
        ],
        supportedLocales: context.supportedLocales,
        debugShowCheckedModeBanner: false,
        theme: theme,
        darkTheme: darkTheme,

        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(
              context.watch<FontSizeProvider>().textScale,
            ),
          ),
          child: child!,
        ),
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
