import 'dart:async';

import 'package:flutter/material.dart';

class TimerWidget extends StatefulWidget {
  final int durationSeconds;
  final VoidCallback onFinished;
  final ValueChanged<int> onChanged;

  const TimerWidget({
    Key? key,
    required this.durationSeconds,
    required this.onFinished,
    required this.onChanged,
  }) : super(key: key);

  @override
  TimerWidgetState createState() => TimerWidgetState();
}

class TimerWidgetState extends State<TimerWidget> {
  late Timer _timer;
  int _counter = 0;

  @override
  void initState() {
    super.initState();
    _counter = widget.durationSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), _onTimerTick);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _onTimerTick(Timer timer) {
    setState(() {
      if (_counter > 0) {
        _counter--;
        widget
            .onChanged(_counter); // Call onChanged to update the remaining time
      } else {
        timer.cancel();
        widget.onFinished();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 60,
      child: _counter > 0
          ? Stack(
              children: [
                CircularProgressIndicator(
                  value: _counter / widget.durationSeconds,
                  backgroundColor: Colors.grey[300],
                  strokeWidth: 5,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Center(
                    child: Text(
                      _counter.toString().padLeft(2, '0'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : const Center(
              child: Text(
                '✔',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ),
    );
  }
}
