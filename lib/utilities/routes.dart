import 'package:echomeet/appointments/create/step1_create_appointment.dart';
import 'package:echomeet/appointments/create/step2_create_appointment.dart';
import 'package:echomeet/appointments/create/step3_create_appointment.dart';
import 'package:echomeet/appointments/main_screen/appointments_dashboard.dart';
import 'package:echomeet/login/login.dart';
import 'package:echomeet/register/register_1step.dart';
import 'package:echomeet/register/register_logics.dart';
import 'package:echomeet/register/registered_sucesfully.dart';
import 'package:echomeet/reset_password/change_password.dart';
import 'package:echomeet/reset_password/reset_password.dart';
import 'package:echomeet/reset_password/reset_verification.dart';
import 'package:echomeet/settings/settings.dart';
import 'package:echomeet/survey_pages/create_survey/step1_create_survey.dart';
import 'package:echomeet/survey_pages/main_sruvey/survey_main.dart';
import 'package:echomeet/utilities/bottom_navigation.dart';
import 'package:flutter/material.dart';

class AppRoutes {
  static Map<String, WidgetBuilder> routes() {
    return {
      '/settings': (BuildContext context) => const SettingsPageUI(),
      '/login': (BuildContext context) => const LoginPage(),
      '/register': (context) => Register1step(
            registerLogic: RegisterLogic(),
          ),
      '/reset_password': (context) => const ResetPasswordPage(),
      '/ResetPasswordVerificationPage': (context) =>
          const ResetPasswordVerificationPage(),
      '/ChangePasswordPage': (context) => const ChangePasswordPage(),
      '/home': (BuildContext context) => const BottomNavigation(),
      '/survey': (BuildContext context) => const AppointmentPageUI(),
      '/create_appointment_step_1': (BuildContext context) =>
          const Step1CreateAppointment(),
      '/create_appointment_step_2': (BuildContext context) =>
          const Step2CreateAppointment(),
      '/create_appointment_step_3': (BuildContext context) =>
          const Step3CreateAppointment(),
      '/registered_successfully': (BuildContext context) =>
          const RegistrationSuccessPage(),
      '/questionary_survey': (BuildContext context) =>
          const QuestionarySurveyPageUI(),
      '/create_training_survey_1': (BuildContext context) =>
          const Step1CreateSurvey(),
    };
  }
}
