import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:survey_app_ks/survey_questionary/user_survey/question_card.dart';
import 'package:survey_app_ks/survey_questionary/user_survey/suvey_finished.dart';
import 'package:survey_app_ks/survey_questionary/utilities/survey_questionary_class.dart';

class QuestionaryTrainingUser extends StatefulWidget {
  final SurveyQuestionaryType survey;
  final Participant participant;

  const QuestionaryTrainingUser({
    Key? key,
    required this.survey,
    required this.participant,
  }) : super(key: key);

  @override
  QuestionaryTrainingUserState createState() => QuestionaryTrainingUserState();
}

class QuestionaryTrainingUserState extends State<QuestionaryTrainingUser> {
  late PageController _pageController;
  ValueNotifier<int> _currentPage = ValueNotifier<int>(0);
  late List<List<dynamic>> _userAnswers;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _pageController = PageController(initialPage: 0);
    _currentPage = ValueNotifier<int>(0);
    _pageController.addListener(() {
      _currentPage.value = _pageController.page!.round();
    });
    _userAnswers = List<List<dynamic>>.generate(
      widget.survey.questions.length,
      (index) => <dynamic>[],
    );
  }

  void _updateUserAnswers(int questionIndex, List<dynamic> userAnswers) {
    setState(() {
      _userAnswers[questionIndex] = userAnswers;
    });
  }

  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
    });

    String userId = _auth.currentUser!.uid;

    Future<DocumentSnapshot> fetchUserFuture =
        FirebaseFirestore.instance.collection('users').doc(userId).get();

    Future<QuerySnapshot> fetchQuestionsFuture = FirebaseFirestore.instance
        .collection('surveys')
        .doc(widget.survey.id)
        .collection('questions')
        .get();

    try {
      var results = await Future.wait([fetchUserFuture, fetchQuestionsFuture]);

      DocumentSnapshot userDoc = results[0] as DocumentSnapshot;
      QuerySnapshot questionSnapshot = results[1] as QuerySnapshot;

      if (userDoc.exists) {
        widget.participant.name = userDoc['fullName'];
      }

      List<Map<String, dynamic>> questions = questionSnapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();

      setState(() {
        questions = questions;
        _isLoading = false;
      });
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Loading...'),
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome ${widget.participant.name.split(' ')[0]}'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: PageView(
                  controller: _pageController,
                  children: List.generate(
                    widget.survey.questions.length,
                    (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 33.0),
                      child: QuestionCard(
                        questionData: widget.survey.questions[index],
                        questionIndex: index,
                        userAnswers: _userAnswers[index],
                        currentPage: _currentPage,
                        onUpdateUserAnswers: _updateUserAnswers,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        if (_currentPage.value > 0) {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.ease,
                          );
                        }
                      },
                    ),
                    ValueListenableBuilder<int>(
                      valueListenable: _currentPage,
                      builder: (context, value, child) {
                        return Text(
                            '${value + 1} / ${widget.survey.questions.length}');
                      },
                    ),
                    buildNavigationButtons()
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildNavigationButtons() {
    return IconButton(
      icon: const Icon(Icons.arrow_forward),
      onPressed: () {
        if (_currentPage.value < widget.survey.questions.length - 1) {
          _pageController.nextPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.ease,
          );
        } else {
          _submitAnswers();
        }
      },
    );
  }

  void _submitAnswers() async {
    Map<String, List<dynamic>> surveyAnswersMap = {};
    double score = 0;
    bool isAnyQuestionNotChosen = false;

    for (int i = 0; i < _userAnswers.length; i++) {
      if (_userAnswers[i].isEmpty) {
        isAnyQuestionNotChosen = true;
        break;
      }

      surveyAnswersMap['Q$i'] = _userAnswers[i];
      if (widget.survey.correctAnswers.length > i &&
          widget.survey.correctAnswers[i].contains(_userAnswers[i])) {
        score += 1;
      }
    }

    if (isAnyQuestionNotChosen) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'please_answer_all_questions'.tr(),
            textAlign: TextAlign.center,
          ),
        ),
      );
      return;
    }

    try {
      String userId = _auth.currentUser!.uid;
      String documentId = "${userId}_${widget.survey.id}";

      await FirebaseFirestore.instance
          .collection('surveyAnswers')
          .doc(documentId)
          .set({
        'userId': userId,
        'surveyId': widget.survey.id,
        'answers': surveyAnswersMap,
        'score': score,
      });

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => FinieshSurveyMessage(
            participant: widget.participant,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving answers: ${e.toString()}'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _currentPage.dispose();
    super.dispose();
  }
}
