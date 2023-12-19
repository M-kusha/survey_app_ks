import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

// ignore: must_be_immutable
class QuestionCard extends StatefulWidget {
  final Map<String, dynamic> questionData;
  final int questionIndex;
  List<dynamic> userAnswers;
  final ValueNotifier<int> currentPage;
  final Function(int, List<dynamic>) onUpdateUserAnswers;

  QuestionCard({
    Key? key,
    required this.questionData,
    required this.questionIndex,
    required this.userAnswers,
    required this.currentPage,
    required this.onUpdateUserAnswers,
  }) : super(key: key);

  @override
  QuestionCardState createState() => QuestionCardState();
}

class QuestionCardState extends State<QuestionCard> {
  late List<dynamic> userAnswers;
  @override
  @override
  void initState() {
    super.initState();
    userAnswers = List<dynamic>.from(widget.userAnswers);
  }

  @override
  void dispose() {
    super.dispose();
  }

  void updateAnswers(List<dynamic> newAnswers) {
    setState(() {
      userAnswers = newAnswers;
    });
  }

  @override
  Widget build(BuildContext context) {
    String type = widget.questionData['type'];
    String question = widget.questionData['question'];
    List<String> options = List<String>.from(widget.questionData['options']);

    Widget answerWidget;

    switch (type) {
      case 'Single':
        answerWidget = StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Column(
              children: options.asMap().entries.map<Widget>((entry) {
                int index = entry.key;
                String option = entry.value;
                bool selected = widget.userAnswers.contains(index);
                return Container(
                  margin: const EdgeInsets.only(bottom: 16.0),
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    color: selected
                        ? Colors.green.withOpacity(0.7)
                        : Theme.of(context).brightness == Brightness.light
                            ? Colors.grey[200]
                            : Colors.grey[800],
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          if (selected) {
                            widget.userAnswers.remove(index);
                          } else {
                            widget.userAnswers.add(index);
                          }
                          options.asMap().forEach((i, option) {
                            if (i != index) {
                              widget.userAnswers.remove(i);
                            }
                          });
                        });
                        widget.onUpdateUserAnswers(
                            widget.questionIndex, widget.userAnswers);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: selected
                                    ? Colors.green.shade700
                                    : Theme.of(context).brightness ==
                                            Brightness.light
                                        ? Colors.grey[200]
                                        : Colors.grey[800],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Center(
                                child: selected
                                    ? Icon(
                                        Icons.check,
                                        size: 16,
                                        color: selected
                                            ? Colors.white
                                            : Theme.of(context).brightness ==
                                                    Brightness.light
                                                ? Colors.black.withOpacity(0.8)
                                                : Colors.white,
                                      )
                                    : Text(
                                        String.fromCharCode(65 + index),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 16.0),
                            Expanded(
                                child: Text(option,
                                    style: TextStyle(
                                      fontSize: 16.0,
                                      fontWeight: FontWeight.bold,
                                      color: selected
                                          ? Colors.white
                                          : Theme.of(context).brightness ==
                                                  Brightness.light
                                              ? Colors.black.withOpacity(0.8)
                                              : Colors.white,
                                    ))),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        );
        break;

      case 'Multiple':
        answerWidget = StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Column(
              children: options.asMap().entries.map<Widget>((entry) {
                int index = entry.key;
                String option = entry.value;
                bool selected = widget.userAnswers.contains(index);
                return Container(
                  margin: const EdgeInsets.only(bottom: 16.0),
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    color: selected
                        ? Colors.green.withOpacity(0.7)
                        : Theme.of(context).brightness == Brightness.light
                            ? Colors.grey[200]
                            : Colors.grey[800],
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          if (selected) {
                            widget.userAnswers.remove(index);
                          } else {
                            widget.userAnswers.add(index);
                          }
                        });
                        widget.onUpdateUserAnswers(
                            widget.questionIndex, widget.userAnswers);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: selected
                                    ? Colors.green.withOpacity(0.5)
                                    : Theme.of(context).brightness ==
                                            Brightness.light
                                        ? Colors.grey[200]
                                        : Colors.grey[800],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Center(
                                child: selected
                                    ? Icon(
                                        Icons.check,
                                        size: 16,
                                        color: selected
                                            ? Colors.white
                                            : Theme.of(context).brightness ==
                                                    Brightness.light
                                                ? Colors.black.withOpacity(0.8)
                                                : Colors.white,
                                      )
                                    : Text(
                                        String.fromCharCode(65 + index),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 16.0),
                            Expanded(
                                child: Text(option,
                                    style: TextStyle(
                                      fontSize: 16.0,
                                      fontWeight: FontWeight.bold,
                                      color: selected
                                          ? Colors.white
                                          : Theme.of(context).brightness ==
                                                  Brightness.light
                                              ? Colors.black.withOpacity(0.8)
                                              : Colors.white,
                                    ))),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        );
        break;

      case 'Text':
        answerWidget = Column(
          children: [
            const SizedBox(height: 16.0),
            TextField(
              onChanged: (value) {
                if (value.length <= 256) {
                  widget.userAnswers = [value];
                } else {
                  widget.userAnswers = [value.substring(0, 256)];
                }
                widget.onUpdateUserAnswers(
                    widget.questionIndex, widget.userAnswers);
              },
              maxLines: null,
              maxLength: 256,
              decoration: InputDecoration(
                hintText: 'enter_your_answer_here'.tr(),
              ),
            ),
          ],
        );
        break;

      default:
        answerWidget = const SizedBox();
    }
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  question,
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).brightness == Brightness.light
                        ? Colors.black.withOpacity(0.8)
                        : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16.0),
                answerWidget,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
