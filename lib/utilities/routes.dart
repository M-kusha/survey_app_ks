import 'package:flutter/material.dart';
import 'package:survey_app_ks/appointments/create/step1_create_appointment.dart';
import 'package:survey_app_ks/appointments/create/step2_create_appointment.dart';
import 'package:survey_app_ks/appointments/create/step3_create_appointment.dart';
import 'package:survey_app_ks/appointments/main_screen/appointments_dashboard.dart';
import 'package:survey_app_ks/reset_password/change_password.dart';
import 'package:survey_app_ks/login/login.dart';
import 'package:survey_app_ks/register/register_1step.dart';
import 'package:survey_app_ks/register/registered_sucesfully.dart';
import 'package:survey_app_ks/reset_password/reset_password.dart';
import 'package:survey_app_ks/reset_password/reset_verification.dart';
import 'package:survey_app_ks/settings/settings.dart';
import 'package:survey_app_ks/survey_pages/create_survey/step1_create_survey.dart';
import 'package:survey_app_ks/survey_pages/main_sruvey/survey_main.dart';
import 'package:survey_app_ks/utilities/bottom_navigation.dart';
import 'package:survey_app_ks/register/register_logics.dart';

class AppRoutes {
  static Map<String, WidgetBuilder> routes() {
    return {
      '/settings': (BuildContext context) => const SettingsPageUI(),
      '/login': (BuildContext context) => const LoginPage(
            message: '',
          ),
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
      // '/create_appointment_step_4': (BuildContext context) =>
      //      Step4CreateAppointment(survey: ),

      // registerred successfully
      '/registered_successfully': (BuildContext context) =>
          const RegistrationSuccessPage(),

      '/questionary_survey': (BuildContext context) =>
          const QuestionarySurveyPageUI(),
      '/create_training_survey_1': (BuildContext context) =>
          const Step1CreateSurvey(),
    };
  }
}
