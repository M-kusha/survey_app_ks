import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:survey_app_ks/appointment/main_survey/survey_main.dart';
import 'package:survey_app_ks/appointment/survey_class.dart';
import 'package:survey_app_ks/appointment/survey_edit/survey_edit_step_1.dart';
import 'package:survey_app_ks/appointment/survey_edit/survey_edit_step_2.dart';
import 'package:survey_app_ks/appointment/survey_edit/survey_edit_step_3.dart';
import 'package:survey_app_ks/appointment/survey_edit/survey_edit_step_4.dart';
import 'package:survey_app_ks/appointment/survey_edit/survey_edit_step_5.dart';
import 'package:survey_app_ks/settings/font_size_provider.dart';
import 'package:survey_app_ks/utilities/tablet_size.dart';

class SurveyEditPage extends StatefulWidget {
  final Survey survey;
  final TimeSlot timeSlot;
  final String userName;

  const SurveyEditPage({
    Key? key,
    required this.survey,
    required this.userName,
    required this.timeSlot,
  }) : super(key: key);

  @override
  SurveyEditPageState createState() => SurveyEditPageState();
}

class SurveyEditPageState extends State<SurveyEditPage> {
  late PageController _pageController;
  late List<Widget> _pages;
  int _currentPageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pages = [
      SurveyEditPageStep1(
        survey: widget.survey,
        onPageChange: _handlePageChange,
      ),
      SurveyEditPageStep2(
        survey: widget.survey,
        onPageChange: _handlePageChange,
      ),
      SurveyEditPageStep3(
        survey: widget.survey,
        onPageChange: _handlePageChange,
      ),
      SurveyEditPage4(
        survey: widget.survey,
        onPageChange: _handlePageChange,
      ),
      SurveyEditPageStep5(
        survey: widget.survey,
        onPageChange: _handlePageChange,
        timeSlot: widget.timeSlot,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          ' ${'survey_edit'.tr()} ${widget.survey.title}',
          style: TextStyle(
            fontSize: timeFontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: PageView(
        controller: _pageController,
        children: _pages,
        onPageChanged: (int index) {
          setState(() {
            _currentPageIndex = index;
          });
        },
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: Size.fromHeight(timeFontSize * 3.0),
                padding: EdgeInsets.symmetric(vertical: timeFontSize * 0.5),
              ),
              onPressed: _handleNextButtonPressed,
              child: Text(
                _currentPageIndex == _pages.length - 1
                    ? 'update_survey'.tr()
                    : 'next'.tr(),
                style: TextStyle(fontSize: fontSize),
              ),
            ),
            const SizedBox(height: 16.0),
          ],
        ),
      ),
    );
  }

  Future<void> _handleNextButtonPressed() async {
    if (_currentPageIndex == _pages.length - 1) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const SurveyPageUI(),
        ),
      );
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentPageIndex++;
      });
    }
  }

  void _handlePageChange(int index) {
    if (index > _currentPageIndex) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
    setState(() {
      _currentPageIndex = index;
    });
  }
}
