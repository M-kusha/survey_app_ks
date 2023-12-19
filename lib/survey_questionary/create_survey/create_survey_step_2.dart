import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:survey_app_ks/settings/font_size_provider.dart';
import 'package:survey_app_ks/survey_questionary/create_survey/create_survey_step_3.dart';
import 'package:survey_app_ks/survey_questionary/utilities/survey_questionary_class.dart';
import 'package:survey_app_ks/utilities/tablet_size.dart';
import 'package:uuid/uuid.dart';

class CreateTrainingSurveyStep2 extends StatefulWidget {
  const CreateTrainingSurveyStep2(
      {Key? key, required this.survey, required this.onSurveyCreated})
      : super(key: key);
  final SurveyQuestionaryType survey;
  final Function(SurveyQuestionaryType) onSurveyCreated;

  @override
  State<CreateTrainingSurveyStep2> createState() =>
      _CreateTrainingSurveyStep2State();
}

class _CreateTrainingSurveyStep2State extends State<CreateTrainingSurveyStep2> {
  final List<Map<String, dynamic>> questions = [];
  late PageController _pageController;
  final ValueNotifier<int> _currentPage = ValueNotifier<int>(0);

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
    setState(() {
      questions.add({
        'type': type,
        'question': '',
        'options': [
          '',
        ],
      });
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              buildCheckbox(type, index, questionData),
              buildAnswerField(questionData, index),
              buildRemoveOptionButton(removeOption, index),
            ],
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
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Center(
        child: Text(
          ' $type  ${'question_type'.tr()} ',
          style: TextStyle(
            fontSize: timeFontSize,
            fontWeight: FontWeight.bold,
            color: Colors.blue[800],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget buildQuestionField(
      String question, Map<String, dynamic> questionData) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'question'.tr(),
          style: TextStyle(
            fontSize: timeFontSize,
            fontWeight: FontWeight.bold,
            color: Colors.blue[800],
          ),
        ),
        const SizedBox(height: 8.0),
        TextFormField(
          initialValue: question,
          decoration: InputDecoration(
            labelText: 'enter_question'.tr(),
            labelStyle: TextStyle(color: Colors.grey, fontSize: timeFontSize),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.blue[800]!),
            ),
          ),
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
        ),
      ],
    );
  }

  Widget buildAnswerLabel() {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);
    return Padding(
      padding: const EdgeInsets.only(bottom: 30),
      child: Text(
        'answer'.tr(),
        style: TextStyle(
          fontSize: timeFontSize,
          fontWeight: FontWeight.bold,
          color: Colors.blue[800],
        ),
      ),
    );
  }

  Widget buildAnswerSection(Widget answerWidget, String type) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
        activeColor: Colors.blue,
      );
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
        checkColor: Colors.white,
        fillColor: MaterialStateProperty.resolveWith<Color>(
            (Set<MaterialState> states) {
          if (states.contains(MaterialState.selected)) {
            return Colors.blue;
          }
          return Colors.grey[300]!; // Checkbox background color
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
        decoration: InputDecoration(
          labelText: '${'answer'.tr()} ${index + 1}',
          labelStyle: TextStyle(color: Colors.grey, fontSize: timeFontSize),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.blue[800]!),
          ),
        ),
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
      ),
    );
  }

  Widget buildRemoveOptionButton(
      void Function(int index) removeOption, int index) {
    return IconButton(
      icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
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
          color: Colors.blue[800],
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
      icon: const Icon(Icons.add_circle_outline, color: Colors.green),
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
              buildQuestionField(question, questionData),
              if (type != 'Text')
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 36.0),
                    buildAnswerLabel(),
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
                icon: const Icon(Icons.add_circle_outline,
                    size: 38, color: Colors.blue),
                onPressed: () {
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
    final SurveyQuestionaryType newSurvey = SurveyQuestionaryType(
      questions: questions,
      correctAnswers: [],
      id: '',
      participants: [],
      surveyDescription: widget.survey.surveyDescription,
      surveyName: widget.survey.surveyName,
      timeCreated: DateTime.now(),
      deadline: widget.survey.deadline,
    );

    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);
    final isAnyFieldEmpty = questions.any((question) {
      if (question['type'] != 'Text') {
        final options = question['options'] as List<String>;
        return options.any((option) => option.isEmpty);
      }
      return question['question'].isEmpty;
    });

    return Center(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          minimumSize: Size(200, timeFontSize * 3.0),
          padding: EdgeInsets.symmetric(vertical: timeFontSize * 0.5),
          side: BorderSide(color: Colors.blue[800]!),
        ),
        onPressed: () async {
          if (questions.isNotEmpty && !isAnyFieldEmpty) {
            final String code = const Uuid().v1().substring(0, 6);
            newSurvey.id = code;
            widget.onSurveyCreated(newSurvey);

            Map<String, dynamic> surveyData = newSurvey.toFirestore();
            await FirebaseFirestore.instance
                .collection('questionary')
                .add(surveyData);

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CreateTrainingSurveyStep3(
                  survey: newSurvey,
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'please_add_question'.tr(),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
        },
        child: Text(
          'finish'.tr(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: timeFontSize,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);
    return Scaffold(
      appBar: AppBar(
        title: Text('create_survey'.tr()),
        centerTitle: true,
      ),
      body: GestureDetector(
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
                        color: Colors.blue[800]!,
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
