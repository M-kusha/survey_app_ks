import 'dart:math';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:survey_app_ks/utilities/text_style.dart';

class QuestionCard extends StatefulWidget {
  final Map<String, dynamic> questionData;
  final int questionIndex;
  final List<dynamic> userAnswers;
  final ValueNotifier<int> currentPage;
  final Function(int, List<dynamic>) onUpdateUserAnswers;
  final int timeLimitPerQuestion;
  final int remainingTime;

  const QuestionCard({
    Key? key,
    required this.questionData,
    required this.questionIndex,
    required this.userAnswers,
    required this.currentPage,
    required this.onUpdateUserAnswers,
    required this.timeLimitPerQuestion,
    required this.remainingTime,
  }) : super(key: key);

  @override
  QuestionCardState createState() => QuestionCardState();
}

class QuestionCardState extends State<QuestionCard>
    with SingleTickerProviderStateMixin {
  late List<dynamic> userAnswers;

  @override
  void initState() {
    super.initState();
    userAnswers = List<dynamic>.from(widget.userAnswers);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Card(
          shadowColor: getButtonColor(context),
          elevation: 5.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildQuestionText(),
                const SizedBox(height: 50),
                _buildAnswerWidget(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionText() {
    return Text(
      widget.questionData['question'],
      style: TextStyle(
        fontSize: 16,
        color: Theme.of(context).brightness == Brightness.light
            ? Colors.black.withOpacity(0.8)
            : Colors.white,
        fontWeight: FontWeight.bold,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildAnswerWidget() {
    final type = widget.questionData['type'];
    final options = List<String>.from(widget.questionData['options']);
    switch (type) {
      case 'Single':
        return _buildOptions(options, isSingleChoice: true);
      case 'Multiple':
        return _buildOptions(options);
      case 'Text':
        return _buildTextAnswer();
      default:
        return const SizedBox();
    }
  }

  Widget _buildOptions(List<String> options, {bool isSingleChoice = false}) {
    return Column(
      children: options.asMap().entries.map((entry) {
        final index = entry.key;
        final option = entry.value;
        final selected = userAnswers.contains(index);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: _buildOption(index, option, selected,
              isSingleChoice: isSingleChoice),
        );
      }).toList(),
    );
  }

  Widget _buildOption(int index, String option, bool selected,
      {bool isSingleChoice = false}) {
    return Card(
      shadowColor: getButtonColor(context),
      elevation: selected ? 3.0 : 1.0,
      color: selected ? getButtonColor(context).withOpacity(0.5) : null,
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        leading: CircleAvatar(
          backgroundColor: selected
              ? getButtonColor(context)
              : Theme.of(context).primaryColorLight,
          child: selected
              ? Icon(Icons.check,
                  color: getTextColor(context),
                  size: 20.0,
                  semanticLabel: 'Selected')
              : Text('${index + 1}',
                  style: const TextStyle(color: Colors.black)),
        ),
        title: Text(
          option,
          style: TextStyle(
            color: selected ? getTextColor(context) : null,
          ),
        ),
        onTap: () => _handleOptionTap(index, isSingleChoice),
      ),
    );
  }

  void _handleOptionTap(int index, bool isSingleChoice) {
    setState(() {
      if (isSingleChoice) {
        userAnswers.clear();
        userAnswers.add(index);
      } else {
        if (userAnswers.contains(index)) {
          userAnswers.remove(index);
        } else {
          userAnswers.add(index);
        }
      }
    });
    widget.onUpdateUserAnswers(widget.questionIndex, userAnswers);
  }

  Widget _buildTextAnswer() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        decoration: InputDecoration(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          hintText: 'enter_your_answer_here'.tr(),
        ),
        onChanged: (value) {
          setState(() {
            userAnswers = [value.substring(0, min(value.length, 256))];
          });
          widget.onUpdateUserAnswers(widget.questionIndex, userAnswers);
        },
        maxLines: null,
        maxLength: 256,
      ),
    );
  }
}
