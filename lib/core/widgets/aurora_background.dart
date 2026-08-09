import 'dart:math' as math;

import 'package:echomeet/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class AuroraBackground extends StatefulWidget {
  const AuroraBackground({super.key, required this.child});

  final Widget child;

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with TickerProviderStateMixin {
  late final AnimationController _slow = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 23),
  );
  late final AnimationController _fast = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 17),
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion || _started) return;
    _started = true;
    _slow.repeat();
    _fast.repeat();
  }

  @override
  void dispose() {
    _slow.dispose();
    _fast.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF080A0F),
                  scheme.surface,
                  const Color(0xFF0B1020),
                ]
              : [
                  const Color(0xFFF7F9FF),
                  scheme.surface,
                  const Color(0xFFEFF3FF),
                ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: Listenable.merge([_slow, _fast]),
              builder: (context, _) => CustomPaint(
                painter: _AuroraPainter(
                  slow: _started ? _slow.value : 0.5,
                  fast: _started ? _fast.value : 0.5,
                  primary: scheme.primary,
                  accent: context.appColors.info,

                  strength: isDark ? 0.24 : 0.14,
                ),
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  const _AuroraPainter({
    required this.slow,
    required this.fast,
    required this.primary,
    required this.accent,
    required this.strength,
  });

  final double slow;
  final double fast;
  final Color primary;
  final Color accent;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    _bloom(
      canvas,
      size,
      center: Offset(
        size.width * (0.22 + 0.16 * math.sin(slow * 2 * math.pi)),
        size.height * (0.18 + 0.10 * math.cos(slow * 2 * math.pi)),
      ),
      radius: size.width * 0.58,
      color: primary,
    );
    _bloom(
      canvas,
      size,
      center: Offset(
        size.width * (0.82 + 0.14 * math.cos(fast * 2 * math.pi)),
        size.height * (0.74 + 0.12 * math.sin(fast * 2 * math.pi)),
      ),
      radius: size.width * 0.50,
      color: accent,
    );
  }

  void _bloom(
    Canvas canvas,
    Size size, {
    required Offset center,
    required double radius,
    required Color color,
  }) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: strength),
            color.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_AuroraPainter old) =>
      old.slow != slow ||
      old.fast != fast ||
      old.primary != primary ||
      old.accent != accent ||
      old.strength != strength;
}
