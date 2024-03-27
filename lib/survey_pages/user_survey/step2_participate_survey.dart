import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:survey_app_ks/survey_pages/user_survey/question_card.dart';
import 'package:survey_app_ks/survey_pages/user_survey/step3_participate_survey.dart';
import 'package:survey_app_ks/survey_pages/utilities/firebase_survey_service.dart';
import 'package:survey_app_ks/survey_pages/utilities/survey_questionary_class.dart';
import 'package:survey_app_ks/utilities/reusable_widgets.dart';
import 'package:survey_app_ks/utilities/text_style.dart';

class Step2ParticipateSurvey extends StatefulWidget {
  final Survey survey;
  final Participant participant;
  final String imageProfile;

  const Step2ParticipateSurvey({
    Key? key,
    required this.survey,
    required this.participant,
    required this.imageProfile,
  }) : super(key: key);

  @override
  Step2ParticipateSurveyState createState() => Step2ParticipateSurveyState();
}

class Step2ParticipateSurveyState extends State<Step2ParticipateSurvey> {
  late PageController _pageController;
  final ValueNotifier<int> _currentPage = ValueNotifier<int>(0);
  late List<List<dynamic>> _userAnswers;
  Timer? _questionTimer;
  int _remainingTime = 0;
  bool get _isTimed => widget.survey.timeLimitPerQuestion > 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _userAnswers = List.generate(widget.survey.questions.length, (_) => []);
    _setupPageListener();
    if (_isTimed) {
      _initTimer();
    }
  }

  void _setupPageListener() {
    _pageController.addListener(() {
      int currentPageIndex = _pageController.page!.round();
      if (_currentPage.value != currentPageIndex) {
        _currentPage.value = currentPageIndex;
        if (_isTimed) {
          _resetTimer(widget.survey.timeLimitPerQuestion);
        }
      }
    });
  }

  void _initTimer() => _resetTimer(widget.survey.timeLimitPerQuestion);

  void _resetTimer(int seconds) {
    _remainingTime = seconds;
    _questionTimer?.cancel();
    if (_isTimed) {
      _questionTimer =
          Timer.periodic(const Duration(seconds: 1), (Timer timer) {
        if (_remainingTime > 0) {
          setState(() => _remainingTime--);
        } else {
          timer.cancel();
          _autoAdvance();
        }
      });
    }
  }

  void _autoAdvance() {
    if (_isTimed &&
        _pageController.page!.round() < widget.survey.questions.length - 1) {
      _pageController.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }

    if (_pageController.page!.round() == widget.survey.questions.length - 1) {
      _submitAnswers();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _questionTimer?.cancel();
    super.dispose();
  }

  void _updateUserAnswers(int questionIndex, List<dynamic> userAnswers) {
    setState(() => _userAnswers[questionIndex] = userAnswers);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _shouldPop(),
      child: Scaffold(
        appBar: AppBar(
          title: Text('Welcome ${widget.participant.name.split(' ')[0]}'),
          centerTitle: true,
          automaticallyImplyLeading:
              widget.survey.surveyType == SurveyType.survey,
          backgroundColor: getAppbarColor(context),
        ),
        body: Padding(
          padding: const EdgeInsets.only(bottom: 50, top: 50),
          child: _buildSurveyContent(),
        ),
      ),
    );
  }

  bool _shouldPop() {
    if (widget.survey.surveyType == SurveyType.test) {
      return false;
    } else {
      return true;
    }
  }

  Widget _buildTimerUI() {
    Color timerColor = getButtonColor(context);
    if (_remainingTime <= 15 && _remainingTime > 5) {
      timerColor = Colors.orange;
    } else if (_remainingTime <= 5) {
      timerColor = Colors.red;
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        CircularProgressIndicator(
          value: _remainingTime / widget.survey.timeLimitPerQuestion.toDouble(),
          valueColor: AlwaysStoppedAnimation<Color>(timerColor),
          backgroundColor: Colors.grey.shade300,
          strokeWidth: 3,
        ),
        Text(
          '$_remainingTime',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.black.withOpacity(0.8)
                : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSurveyContent() {
    return Stack(children: [
      _buildPageView(),
      _buildNavigationControls(),
      const SizedBox(
        height: 50,
      )
    ]);
  }

  Widget _buildPageView() {
    return Center(
      child: PageView.builder(
        controller: _pageController,
        physics: _isTimed ? const NeverScrollableScrollPhysics() : null,
        itemCount: widget.survey.questions.length,
        itemBuilder: (context, index) => QuestionCard(
          questionData: widget.survey.questions[index],
          questionIndex: index,
          userAnswers: _userAnswers[index],
          currentPage: _currentPage,
          onUpdateUserAnswers: _updateUserAnswers,
          timeLimitPerQuestion: widget.survey.timeLimitPerQuestion,
          remainingTime: _remainingTime,
        ),
      ),
    );
  }

  Widget _buildNavigationControls() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (!_isTimed) _buildBackButton(),
            if (_isTimed)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: _buildTimerUI(),
              ),
            _buildPageIndicator(),
            _buildForwardButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: _currentPage.value > 0
          ? () => _pageController.previousPage(
              duration: const Duration(milliseconds: 300), curve: Curves.ease)
          : null,
    );
  }

  Widget _buildPageIndicator() {
    return ValueListenableBuilder<int>(
      valueListenable: _currentPage,
      builder: (context, value, child) =>
          Text('${value + 1} / ${widget.survey.questions.length}'),
    );
  }

  Widget _buildForwardButton() {
    return IconButton(
      icon: const Icon(Icons.arrow_forward),
      onPressed: () {
        if (_currentPage.value < widget.survey.questions.length - 1) {
          _pageController.nextPage(
              duration: const Duration(milliseconds: 300), curve: Curves.ease);
        } else {
          _submitAnswers();
        }
      },
    );
  }

  void _submitAnswers() async {
    setState(() {});

    bool timerActive = widget.survey.timeLimitPerQuestion > 0;
    Map<String, List<dynamic>> surveyAnswersMap = {};

    for (int i = 0; i < widget.survey.questions.length; i++) {
      surveyAnswersMap['Q$i'] = _userAnswers[i];
    }

    bool isAnyQuestionNotChosen =
        _userAnswers.any((answers) => answers.isEmpty);
    if (!timerActive && isAnyQuestionNotChosen) {
      UIUtils.showSnackBar(context, 'please_answer_all_questions'.tr());

      setState(() {});
      return;
    }

    int totalCorrectAnswers = calculateCorrectAnswers();

    double score = calculateScore();
    widget.participant.score = score;
    widget.participant.surveyAnswers = surveyAnswersMap;
    widget.participant.participantSubmitted;
    widget.participant.totalCorrectAnswers = totalCorrectAnswers;

    try {
      await FirebaseSurveyService().submitSurveyAnswers(
        surveyId: widget.survey.id,
        participant: widget.participant,
        answers: surveyAnswersMap,
        score: score,
        imageProfile: widget.imageProfile,
        textAnswersReviewed: widget.participant.textAnswersReviewed,
        totalCorrectAnswers: totalCorrectAnswers,
      );
      if (!context.mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (context) => Step3ParticipateSurvey(
              participant: widget.participant, survey: widget.survey)));
    } catch (e) {
      UIUtils.showSnackBar(context, 'error_occurred'.tr());
    } finally {
      setState(() {});
    }
  }

  // calculate correct answers

  int calculateCorrectAnswers() {
    int totalCorrectAnswers = 0;

    for (int i = 0; i < widget.survey.questions.length; i++) {
      Map<String, dynamic> question = widget.survey.questions[i];
      List<dynamic> userAnswers = _userAnswers[i];

      if (userAnswers.isNotEmpty) {
        bool isCorrect = false;

        if (question['type'] == 'Single') {
          if (userAnswers.first == question['correctAnswer']) {
            isCorrect = true;
          }
        } else if (question['type'] == 'Multiple') {
          List<dynamic> correctAnswers = question['correctAnswers'];
          Set<dynamic> userAnswersSet = Set.from(userAnswers);
          Set<dynamic> correctAnswersSet = Set.from(correctAnswers);

          if (userAnswersSet.length == correctAnswersSet.length &&
              userAnswersSet.containsAll(correctAnswersSet)) {
            isCorrect = true;
          }
        }

        if (isCorrect) {
          totalCorrectAnswers++;
        }
      }
    }

    return totalCorrectAnswers;
  }

  double calculateScore() {
    double totalScore = 0.0;

    for (int i = 0; i < widget.survey.questions.length; i++) {
      Map<String, dynamic> question = widget.survey.questions[i];
      List<dynamic> userAnswers = _userAnswers[i];

      if (userAnswers.isNotEmpty) {
        double questionScore = 0.0;

        if (question['type'] == 'Single') {
          if (userAnswers.first == question['correctAnswer']) {
            questionScore = 1.0;
          }
        } else if (question['type'] == 'Multiple') {
          List<dynamic> correctAnswers = question['correctAnswers'];
          Set<dynamic> userAnswersSet = Set.from(userAnswers);
          Set<dynamic> correctAnswersSet = Set.from(correctAnswers);

          int correctCount =
              userAnswersSet.intersection(correctAnswersSet).length;

          if (correctCount > 0) {
            questionScore = correctCount / correctAnswersSet.length;
          }
        }

        totalScore += questionScore / widget.survey.questions.length;
      }
    }

    return totalScore * 100;
  }
}
