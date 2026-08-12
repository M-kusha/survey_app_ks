import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The EchoMeet mark: an arc and its echo.
///
/// Drawn rather than picked from an icon set, because the rail previously used
/// a calendar glyph in a gradient square — a placeholder that said "some app"
/// and borrowed its only visual interest from the gradient.
///
/// The form comes from the name: one arc, then the same arc again further out
/// and lighter, the way a sound returns. Two facing arcs were tried first and
/// read as empty brackets at 16px — a pair of thin slivers with a hole between
/// them. Nesting them puts the strokes close enough to be read as one mark at
/// rail size, and the weight difference is what makes it an echo rather than a
/// target.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 24, this.color});

  final double size;

  /// Defaults to the current text colour, so the mark inherits the emphasis of
  /// whatever it sits next to rather than asserting its own.
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
    // Proportional to the box, so the mark reads the same at 16px and at 96px
    // rather than turning into a hairline or a blob. The weight is deliberately
    // light relative to the gap between the arcs: heavier and they fused into a
    // single crescent at rail size, which lost the echo entirely.
    final weight = size.width * 0.10;
    // The arcs only occupy the right of their circle, so centring the circle
    // would leave the ink visibly off to one side. This centres the ink.
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

    // The call, then its return: same arc, further out and quieter. Drawn
    // inner-first so the heavier stroke sits on top where they nearly meet.
    arc(0.38, 0.45);
    arc(0.20, 1);
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => oldDelegate.color != color;
}
