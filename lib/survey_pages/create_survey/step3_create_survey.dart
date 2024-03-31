import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/settings/font_size_provider.dart';
import 'package:echomeet/survey_pages/create_survey/step4_create_survey.dart';
import 'package:echomeet/survey_pages/utilities/firebase_survey_service.dart';
import 'package:echomeet/survey_pages/utilities/survey_questionary_class.dart';
import 'package:echomeet/utilities/reusable_widgets.dart';
import 'package:echomeet/utilities/tablet_size.dart';
import 'package:echomeet/utilities/text_style.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CreateTrainingSurveyStep3 extends StatefulWidget {
  const CreateTrainingSurveyStep3({
    super.key,
    required this.survey,
  });
  final Survey survey;

  @override
  State<CreateTrainingSurveyStep3> createState() =>
      _CreateTrainingSurveyStep3State();
}

class _CreateTrainingSurveyStep3State extends State<CreateTrainingSurveyStep3> {
  final List<Map<String, dynamic>> questions = [];
  late PageController _pageController;
  final ValueNotifier<int> _currentPage = ValueNotifier<int>(0);
  bool _isCreatingSurvey = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageController.addListener(() {
      _currentPage.value = _pageController.page!.round();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _currentPage.dispose();
    super.dispose();
  }

  void addQuestion(String type) {
    List<String> initialOptions = [];
    Map<String, dynamic> newQuestion = {
      'type': type,
      'question': '',
    };

    if (type == 'Single' || type == 'Multiple') {
      initialOptions = ['', '', '', ''];
      newQuestion.addAll({'options': initialOptions});
    } else if (type == 'Text') {
      newQuestion.addAll({'options': initialOptions});
    }

    setState(() {
      questions.add(newQuestion);
    });

    _pageController.jumpToPage(questions.length - 1);
  }

  Widget _buildQuestionCard(Map<String, dynamic> questionData) {
    String type = questionData['type'];
    String question = questionData['question'];

    void addOption() {
      setState(() {
        questionData['options'].add('');
      });
    }

    void removeOption(int index) {
      setState(() {
        questionData['options'].removeAt(index);
      });
    }

    Widget buildOptions(int index) {
      return Column(
        children: [
          Card(
            margin: const EdgeInsets.all(3.0),
            shadowColor: getButtonColor(context),
            elevation: 5,
            child: SizedBox(
              height: 60,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  widget.survey.surveyType == SurveyType.survey
                      ? const SizedBox(width: 20)
                      : buildCheckbox(type, index, questionData),
                  buildAnswerField(questionData, index),
                  buildRemoveOptionButton(removeOption, index),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16.0),
        ],
      );
    }

    Widget answerWidget;

    switch (type) {
      case 'Single':
        answerWidget =
            buildSingleOrMultipleChoice(questionData, buildOptions, addOption);
        break;
      case 'Multiple':
        answerWidget =
            buildSingleOrMultipleChoice(questionData, buildOptions, addOption);
        break;
      case 'Text':
        answerWidget = buildTextAnswer(questionData);

        break;
      default:
        throw Exception('Invalid question type');
    }

    return buildCard(questionData, question, answerWidget, type);
  }

  Widget buildSingleOrMultipleChoice(Map<String, dynamic> questionData,
      Widget Function(int index) buildOptions, Function addOption) {
    return Column(
      children: [
        for (int i = 0; i < questionData['options'].length; i++)
          buildOptions(i),
        buildAddOptionButton(addOption),
      ],
    );
  }

  Widget buildQuestionTitle(String type) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);
    String questionTypeDescription;
    switch (type) {
      case 'Single':
        questionTypeDescription = tr('single_choice');
        break;
      case 'Multiple':
        questionTypeDescription = tr('multiple_choice');
        break;
      case 'Text':
        questionTypeDescription = tr('text_answer');
        break;
      default:
        questionTypeDescription = '';
    }
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Center(
        child: Text(
          questionTypeDescription,
          style: TextStyle(
              fontSize: timeFontSize,
              fontWeight: FontWeight.bold,
              color: getListTileColor(context)),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget buildQuestionField(
      String question, Map<String, dynamic> questionData) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);

    return TextFormField(
      initialValue: question,
      onChanged: (value) {
        setState(() {
          questionData['question'] = value;
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'please_enter_question'.tr();
        }
        return null;
      },
      style: TextStyle(
          fontSize: timeFontSize * 1.0, color: getListTileColor(context)),
      textAlign: TextAlign.center,
      keyboardType: TextInputType.multiline,
      maxLines: null,
      maxLength: 256,
      decoration: InputDecoration(
        labelStyle: TextStyle(color: Colors.grey, fontSize: timeFontSize),
        focusedBorder: InputBorder.none,
        enabledBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        border: InputBorder.none,
        hintText: 'enter_question'.tr(),
        hintStyle: TextStyle(color: Colors.grey[500]),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 10,
        ),
        counterStyle: TextStyle(
          color: Colors.grey[600],
          fontSize: timeFontSize * 0.8,
        ),
      ),
    );
  }

  Widget buildAnswerSection(Widget answerWidget, String type) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        answerWidget,
        if (type == 'Single' || type == 'Multiple')
          Center(
            child: Text(
              'create_survey_tips'.tr(),
              style: TextStyle(
                color: Colors.grey[400],
                fontStyle: FontStyle.italic,
                fontSize: timeFontSize - 4,
              ),
            ),
          ),
      ],
    );
  }

  Widget buildCheckbox(
      String type, int index, Map<String, dynamic> questionData) {
    if (type == 'Single') {
      int? correctAnswerIndex = questionData['correctAnswer'];
      return Checkbox(
          value: correctAnswerIndex == index,
          onChanged: (value) {
            setState(() {
              if (value!) {
                correctAnswerIndex = index;
              } else {
                correctAnswerIndex = null;
              }
              questionData['correctAnswer'] = correctAnswerIndex;
            });
          },
          activeColor: getButtonColor(context));
    } else {
      List<int> correctAnswerIndices = questionData['correctAnswers'] ?? [];
      return Checkbox(
        value: correctAnswerIndices.contains(index),
        onChanged: (value) {
          setState(() {
            if (value!) {
              correctAnswerIndices.add(index);
            } else {
              correctAnswerIndices.remove(index);
            }
            questionData['correctAnswers'] = correctAnswerIndices;
          });
        },
        checkColor: getTextColor(context),
        fillColor: MaterialStateProperty.resolveWith<Color>(
            (Set<MaterialState> states) {
          if (states.contains(MaterialState.selected)) {
            return getButtonColor(context);
          }
          return getTextColor(context);
        }),
      );
    }
  }

  Widget buildAnswerField(Map<String, dynamic> questionData, int index) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);

    return Expanded(
      child: TextFormField(
        initialValue: questionData['options'][index],
        onChanged: (value) {
          setState(() {
            questionData['options'][index] = value;
          });
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'please_enter_option'.tr();
          }
          return null;
        },
        style:
            TextStyle(fontSize: timeFontSize, color: getListTileColor(context)),
        decoration: InputDecoration(
          labelStyle:
              TextStyle(color: Colors.grey[400], fontSize: timeFontSize),
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          border: InputBorder.none,
          hintText: '${'answer'.tr()} ${index + 1}',
          hintStyle: TextStyle(color: Colors.grey[500]),
        ),
      ),
    );
  }

  Widget buildRemoveOptionButton(
      void Function(int index) removeOption, int index) {
    return IconButton(
      icon: const Icon(Icons.close, color: Colors.red),
      onPressed: () => removeOption(index),
    );
  }

  Widget buildTextAnswer(Map<String, dynamic> questionData) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);
    return TextFormField(
      initialValue: questionData['correctAnswer'],
      decoration: InputDecoration(
        labelStyle: TextStyle(
          color: getButtonColor(context), //getColor(context, 'buttonColor'
          fontWeight: FontWeight.bold,
          fontSize: timeFontSize,
        ),
        hintText: 'enter_answer'.tr(),
        hintStyle: TextStyle(
          color: Colors.grey[400],
          fontStyle: FontStyle.italic,
          fontSize: timeFontSize,
        ),
      ),
      onChanged: (value) {
        setState(() {
          questionData['correctAnswer'] = value;
        });
      },
    );
  }

  Widget buildAddOptionButton(Function addOption) {
    return IconButton(
      icon: Icon(
        Icons.add_circle_outline,
        color: getButtonColor(context),
      ),
      onPressed: () => addOption(),
    );
  }

  Widget buildCard(Map<String, dynamic> questionData, String question,
      Widget answerWidget, String type) {
    return Card(
      margin: const EdgeInsets.all(3.0),
      elevation: 4.0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildQuestionTitle(type),
              const SizedBox(height: 16.0),
              Card(
                elevation: 5,
                shadowColor: getButtonColor(context),
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 40,
                    right: 40,
                  ),
                  child: buildQuestionField(question, questionData),
                ),
              ),
              if (type != 'Text')
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 36.0),
                    buildAnswerSection(answerWidget, type),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddQuestionPage() {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 200.0),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(
                  Icons.add_circle_outline,
                  size: 38,
                  color: getButtonColor(context),
                ),
                onPressed: () {
                  if (widget.survey.surveyType == SurveyType.survey) {
                    addQuestion('Single');
                  } else {
                    showModalBottomSheet(
                      context: context,
                      builder: (context) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              title: Text('single_choice_question'.tr()),
                              onTap: () {
                                addQuestion('Single');
                                Navigator.pop(context);
                              },
                            ),
                            ListTile(
                              title: Text('multiple_choice_question'.tr()),
                              onTap: () {
                                addQuestion('Multiple');
                                Navigator.pop(context);
                              },
                            ),
                            ListTile(
                              title: Text('text_question'.tr()),
                              onTap: () {
                                addQuestion('Text');
                                Navigator.pop(context);
                              },
                            ),
                          ],
                        );
                      },
                    );
                  }
                },
              ),
              const SizedBox(height: 16.0),
              Text(
                'add_question'.tr(),
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: timeFontSize,
                ),
              ),
            ],
          ),
        ),
        Expanded(
            child: Align(
                alignment: Alignment.bottomCenter,
                child: _buildFinishButton())),
      ],
    );
  }

  Widget _buildFinishButton() {
    final fontSize =
        Provider.of<FontSizeProvider>(context, listen: false).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);

    void attemptSurveySubmission() {
      bool isAnyFieldEmpty = questions.any((question) {
        if (question['type'] != 'Text') {
          final options = List<String>.from(question['options']);
          // Check if any option is empty
          return options.any((option) => option.trim().isEmpty);
        }

        return question['question'].trim().isEmpty;
      });

      if (isAnyFieldEmpty || questions.isEmpty) {
        UIUtils.showSnackBar(context, 'empty_fields_warning'.tr());
        return;
      }

      _handleSurveySubmission();
    }

    return Center(
      child: ElevatedButton(
        style: OutlinedButton.styleFrom(
          minimumSize: Size(250, timeFontSize * 4.0),
          padding: EdgeInsets.symmetric(vertical: timeFontSize * 0.5),
          side: BorderSide(
            color: getButtonColor(context),
          ),
        ),
        onPressed: () => attemptSurveySubmission(),
        child: Text(
          tr('continue'),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: timeFontSize * 1.3,
          ),
        ),
      ),
    );
  }

  void _handleSurveySubmission() async {
    if (!validateSurveySubmission()) {
      return;
    }
    setState(() {
      _isCreatingSurvey = true;
    });

    Survey newSurvey = Survey(
      surveyName: widget.survey.surveyName,
      surveyDescription: widget.survey.surveyDescription,
      timeCreated: DateTime.now(),
      questions: questions,
      id: '',
      participants: [],
      deadline: widget.survey.deadline,
      timeLimitPerQuestion: widget.survey.timeLimitPerQuestion,
      surveyType: widget.survey.surveyType,
      companyId: widget.survey.companyId,
    );

    try {
      String? companyId =
          await FirebaseSurveyService().fetchCurrentUserCompanyId();
      newSurvey.companyId = companyId ?? '';
      if (!mounted) return;
      String surveyId = await FirebaseSurveyService().createSurvey(newSurvey);
      newSurvey.id = surveyId;
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => Step4CreateSurvey(survey: newSurvey),
        ),
      );
    } catch (e) {
      UIUtils.showSnackBar(context, 'error_occurred'.tr() + e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingSurvey = false;
        });
      }
    }
  }

  bool validateSurveySubmission() {
    for (var question in questions) {
      if (question['question'].trim().isEmpty) {
        UIUtils.showSnackBar(context, 'question_empty_warning'.tr());
        return false;
      }

      if (widget.survey.surveyType == SurveyType.test) {
        if (question['type'] == 'Single') {
          int? correctAnswerIndex = question['correctAnswer'];
          if (correctAnswerIndex == null) {
            UIUtils.showSnackBar(
                context, 'single_choice_validation_warning'.tr());
            return false;
          }
        }

        if (question['type'] == 'Multiple') {
          List<int> correctAnswerIndices = question['correctAnswers'] ?? [];
          if (correctAnswerIndices.length < 2) {
            UIUtils.showSnackBar(
                context, 'multiple_choice_validation_warning'.tr());
            return false;
          }
        }
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);
    return Scaffold(
      appBar: AppBar(
        title: Text('create_survey'.tr()),
        centerTitle: true,
        backgroundColor: getAppbarColor(context),
      ),
      body: _isCreatingSurvey
          ? const Center(
              child: CustomLoadingWidget(
              loadingText: 'saving_regisration',
            ))
          : GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: Stack(
                children: [
                  PageView(
                    controller: _pageController,
                    children: [
                      ...List.generate(questions.length, (index) {
                        return _buildQuestionCard(questions[index]);
                      }),
                      _buildAddQuestionPage(),
                    ],
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 32.0,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: ValueListenableBuilder<int>(
                        valueListenable: _currentPage,
                        builder: (context, value, child) {
                          return Text(
                            '${'survey_question'.tr()} ${value + 1}/${questions.length}',
                            style: TextStyle(
                              fontSize: timeFontSize,
                              fontWeight: FontWeight.bold,
                              color: getButtonColor(context),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
