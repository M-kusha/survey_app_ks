import 'dart:math' as math;

import 'package:flutter/material.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 24, this.color});

  final double size;

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolved =
        color ??
        DefaultTextStyle.of(context).style.color ??
        Theme.of(context).colorScheme.onSurface;

    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _MarkPainter(resolved)),
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter(this.color);

  final Color color;

  static const _degree = math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final weight = size.width * 0.10;

    final centre = Offset(size.width * 0.26, size.height / 2);

    Paint strokeAt(double alpha) => Paint()
      ..color = color.withValues(alpha: color.a * alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = weight
      ..strokeCap = StrokeCap.round;

    void arc(double radiusFactor, double alpha) => canvas.drawArc(
      Rect.fromCircle(center: centre, radius: size.width * radiusFactor),
      -58 * _degree,
      116 * _degree,
      false,
      strokeAt(alpha),
    );

    arc(0.38, 0.45);
    arc(0.20, 1);
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => oldDelegate.color != color;
}
