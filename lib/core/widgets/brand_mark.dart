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

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width * 0.305;
    final centre = Offset(size.width / 2, size.height / 2);
    final left = centre.translate(-size.width * 0.145, 0);
    final right = centre.translate(size.width * 0.145, 0);

    final leftCircle = Path()
      ..addOval(Rect.fromCircle(center: left, radius: radius));
    final rightCircle = Path()
      ..addOval(Rect.fromCircle(center: right, radius: radius));

    final wash = Paint()..color = color.withValues(alpha: color.a * 0.55);
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawPath(leftCircle, wash);
    canvas.drawPath(rightCircle, wash);
    canvas.restore();

    canvas.drawPath(
      Path.combine(PathOperation.intersect, leftCircle, rightCircle),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => oldDelegate.color != color;
}
