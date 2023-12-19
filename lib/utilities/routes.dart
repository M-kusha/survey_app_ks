import 'package:flutter/material.dart';
import 'package:survey_app_ks/appointment/create_survey/create_survey_step_1.dart';
import 'package:survey_app_ks/appointment/create_survey/create_survey_step_2.dart';
import 'package:survey_app_ks/appointment/create_survey/create_survey_step_3.dart';
import 'package:survey_app_ks/appointment/create_survey/create_survey_step_4.dart';
import 'package:survey_app_ks/appointment/main_survey/survey_main.dart';
import 'package:survey_app_ks/login/change_password.dart';
import 'package:survey_app_ks/login/login.dart';
import 'package:survey_app_ks/login/register.dart';
import 'package:survey_app_ks/login/reset_password.dart';
import 'package:survey_app_ks/login/reset_verification.dart';
import 'package:survey_app_ks/settings/settings.dart';
import 'package:survey_app_ks/survey_questionary/create_survey/create_survey_step_1.dart';
import 'package:survey_app_ks/survey_questionary/main_sruvey/survey_main.dart';
import 'package:survey_app_ks/utilities/bottom_navigation.dart';

class AppRoutes {
  static Map<String, WidgetBuilder> routes() {
    return {
      '/settings': (BuildContext context) => const SettingsPageUI(),
      '/login': (BuildContext context) => const LoginPage(
            message: '',
          ),
      '/register': (context) => const RegisterPage(),
      '/reset_password': (context) => const ResetPasswordPage(),
      '/ResetPasswordVerificationPage': (context) =>
          const ResetPasswordVerificationPage(),
      '/ChangePasswordPage': (context) => const ChangePasswordPage(),
      '/home': (BuildContext context) => const BottomNavigation(),
      '/survey': (BuildContext context) => const SurveyPageUI(),
      '/create_survey_1': (BuildContext context) => const CreateSurveyStep1(),
      '/create_survey_2': (BuildContext context) => const CreateSurveyStep2(),
      '/create_survey_3': (BuildContext context) => const CreateSurveyStep3(),
      '/create_survey_4': (BuildContext context) => CreateSurveyStep4(
            onSurveyCreated: (survey) {},
          ),
      '/questionary_survey': (BuildContext context) =>
          const QuestionarySurveyPageUI(),
      '/create_training_survey_1': (BuildContext context) =>
          const CreateTrainingSurveyStep1(),
    };
  }
}
