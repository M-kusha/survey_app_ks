import 'package:echomeet/appointments/create/step1_create_appointment.dart';
import 'package:echomeet/appointments/create/step2_create_appointment.dart';
import 'package:echomeet/appointments/create/step3_create_appointment.dart';
import 'package:echomeet/login/login.dart';
import 'package:echomeet/login/session_access.dart';
import 'package:echomeet/register/register_1step.dart';
import 'package:echomeet/register/deferred_onboarding.dart';
import 'package:echomeet/register/register_logics.dart';
import 'package:echomeet/register/registered_sucesfully.dart';
import 'package:echomeet/reset_password/reset_password.dart';
import 'package:echomeet/settings/account_deletion_info.dart';
import 'package:echomeet/settings/settings.dart';
import 'package:echomeet/survey_pages/create_survey/step1_create_survey.dart';
import 'package:echomeet/survey_pages/main_sruvey/survey_main.dart';
import 'package:echomeet/utilities/bottom_navigation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AppRoutes {
  static Map<String, WidgetBuilder> routes() {
    return {
      '/settings': (context) => _protected(context, const SettingsPageUI()),
      '/login': (BuildContext context) => const LoginPage(),
      '/register': (context) {
        final logic = context.read<RegisterLogic>()..resetForRegistration();
        return Register1step(registerLogic: logic);
      },
      '/reset_password': (context) => const ResetPasswordPage(),
      '/account-deletion': (context) => const AccountDeletionInfoPage(),
      '/home': (context) => _protected(context, const BottomNavigation()),
      '/survey': (context) =>
          _protected(context, const QuestionarySurveyPageUI()),
      '/create_appointment_step_1': (context) =>
          _protected(context, const Step1CreateAppointment()),
      '/create_appointment_step_2': (context) =>
          _protected(context, const Step2CreateAppointment()),
      '/create_appointment_step_3': (context) =>
          _protected(context, const Step3CreateAppointment()),
      '/registered_successfully': (BuildContext context) =>
          const RegistrationSuccessPage(),
      '/questionary_survey': (context) =>
          _protected(context, const QuestionarySurveyPageUI()),
      '/create_training_survey_1': (context) =>
          _protected(context, const Step1CreateSurvey()),
    };
  }

  static Widget _protected(BuildContext context, Widget child) {
    final signedIn = FirebaseAuth.instance.currentUser != null;
    final unlocked = context.watch<SessionAccess>().isUnlocked;
    return signedIn && unlocked
        ? DeferredOnboardingGate(child: child)
        : const LoginPage();
  }
}
