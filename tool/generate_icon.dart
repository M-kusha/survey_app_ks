import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Paints the app icon and writes the source images the platforms build from.
///
///     flutter test tool/generate_icon.dart
///
/// The mark is drawn rather than shipped as a binary: a PNG in a repository is
/// something nobody can edit or explain six months later, whereas this states
/// the geometry, and re-running it after a brand change costs one command.
///
/// Every candidate here has to survive being 48px on a home screen, where only
/// the silhouette is left. That rules out anything with fine detail, thin
/// strokes, or a glyph that needs to be read rather than recognised — and it is
/// why an earlier attempt (a point with arcs radiating from it) was abandoned:
/// at any size it was a Wi-Fi symbol, and an icon that reads as a system
/// indicator is worse than a dull one.
void main() {
  const size = 1024.0;

  // The app's own palette, so the icon cannot drift away from the product it
  // opens.
  const deep = Color(0xFF00306B);
  const bright = Color(0xFF1E7BE0);

  /// Which mark to ship. The others stay in the file as the record of what was
  /// considered — deleting them just means the next person re-invents them.
  const chosen = _Mark.echo;

  test('generates the icon sources', () async {
    await _write('assets/icon/icon.png', size, (canvas) {
      _paintTile(canvas, size, deep, bright, rounded: false);
      chosen.paint(canvas, size, 1);
    });

    // Android draws adaptive icons as a foreground over a background, masked to
    // whatever shape the launcher wants — circle, squircle, teardrop.
    //
    // Drawn at full size, not shrunk. The safe area is already handled: the
    // generated `ic_launcher.xml` wraps this in a 16% inset, and the mark's own
    // extent is 66% of the frame, so it lands at roughly two thirds of the
    // visible circle — which is where it should be. Scaling it down here as
    // well stacked the two margins and left it swimming in space.
    await _write('assets/icon/icon_foreground.png', size, (canvas) {
      chosen.paint(canvas, size, 1);
    });

    // The layer underneath it. A flat colour would have done, but the gradient
    // is what makes the icon look like the app rather than like a swatch, and
    // losing it only on Android would be the sort of inconsistency nobody
    // notices until they own both devices.
    await _write('assets/icon/icon_background.png', size, (canvas) {
      _paintTile(canvas, size, deep, bright, rounded: false);
    });

    for (final path in const [
      'assets/icon/icon.png',
      'assets/icon/icon_foreground.png',
      'assets/icon/icon_background.png',
    ]) {
      expect(File(path).lengthSync(), greaterThan(2000), reason: path);
    }
  });

  test('renders every candidate for comparison', () async {
    for (final mark in _Mark.values) {
      await _write('build/icon-preview/${mark.name}.png', size, (canvas) {
        _paintTile(canvas, size, deep, bright, rounded: true);
        mark.paint(canvas, size, 1);
      });
    }
  });
}

enum _Mark {
  /// The mark the app itself draws: an arc and its echo. Shipping anything else
  /// here means the icon and the product disagree about what the logo is.
  echo,

  /// Two circles meeting, with the lens between them lit. What the app does:
  /// find the time a group can all make, the answers a company shares.
  overlap,

  /// Three bars of unequal length. A tally, and an E without its spine.
  tally,

  /// A ring closed by a tick. A question put to a group and answered.
  answered;

  void paint(Canvas canvas, double size, double scale) {
    canvas.save();
    // Scaled about the centre, so the adaptive foreground is the same drawing
    // simply held further from the edges.
    canvas.translate(size / 2, size / 2);
    canvas.scale(scale);
    canvas.translate(-size / 2, -size / 2);

    switch (this) {
      case _Mark.echo:
        _paintEcho(canvas, size);
      case _Mark.overlap:
        _paintOverlap(canvas, size);
      case _Mark.tally:
        _paintTally(canvas, size);
      case _Mark.answered:
        _paintAnswered(canvas, size);
    }

    canvas.restore();
  }
}

void _paintEcho(Canvas canvas, double size) {
  const degree = math.pi / 180;

  // The same geometry BrandMark paints, in the same proportions, so the icon and
  // the mark in the rail are one drawing at two sizes. Heavier here: an icon is
  // seen at 48px against a wallpaper, where the widget's weight thins out.
  // BrandMark's ratios, not guessed ones: stroke half the inner radius, outer
  // radius 1.9x the inner. At a heavier stroke the inner arc fills in and the
  // mark reads as a solid kidney shape instead of an arc.
  final weight = size * 0.079;
  final centre = Offset(size * 0.308, size / 2);

  Paint strokeAt(double alpha) => Paint()
    ..color = Colors.white.withValues(alpha: alpha)
    ..style = PaintingStyle.stroke
    ..strokeWidth = weight
    ..strokeCap = StrokeCap.round;

  void arc(double radiusFactor, double alpha) => canvas.drawArc(
    Rect.fromCircle(center: centre, radius: size * radiusFactor),
    -58 * degree,
    116 * degree,
    false,
    strokeAt(alpha),
  );

  arc(0.300, 0.5);
  arc(0.158, 1);
}

void _paintOverlap(Canvas canvas, double size) {
  final radius = size * 0.225;
  final centre = Offset(size / 2, size / 2);
  final left = centre.translate(-size * 0.105, 0);
  final right = centre.translate(size * 0.105, 0);

  final leftPath = Path()
    ..addOval(Rect.fromCircle(center: left, radius: radius));
  final rightPath = Path()
    ..addOval(Rect.fromCircle(center: right, radius: radius));

  final wash = Paint()..color = Colors.white.withValues(alpha: 0.55);
  canvas.drawPath(leftPath, wash);
  canvas.drawPath(rightPath, wash);

  // The lens: where the two agree, at full strength. This is the whole idea,
  // so it is the brightest thing in the frame.
  canvas.drawPath(
    Path.combine(PathOperation.intersect, leftPath, rightPath),
    Paint()..color = Colors.white,
  );
}

void _paintTally(Canvas canvas, double size) {
  // Unequal lengths on purpose. Three equal bars is a hamburger menu.
  const bars = [0.86, 0.54, 0.70];
  final height = size * 0.088;
  final gap = size * 0.072;
  final left = size * 0.22;
  final top = size / 2 - (bars.length * height + (bars.length - 1) * gap) / 2;

  for (var i = 0; i < bars.length; i++) {
    final y = top + i * (height + gap);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, y, size * 0.56 * bars[i], height),
        Radius.circular(height / 2),
      ),
      Paint()..color = Colors.white.withValues(alpha: i == 0 ? 1 : 0.62),
    );
  }
}

void _paintAnswered(Canvas canvas, double size) {
  final centre = Offset(size / 2, size / 2);
  final radius = size * 0.255;
  final stroke = size * 0.082;

  // An open ring — the gap is where the tick enters, so the two read as one
  // shape rather than a tick sitting on top of a circle.
  canvas.drawArc(
    Rect.fromCircle(center: centre, radius: radius),
    -2.0,
    5.0,
    false,
    Paint()
      ..color = Colors.white.withValues(alpha: 0.62)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round,
  );

  canvas.drawPath(
    Path()
      ..moveTo(size * 0.375, size * 0.505)
      ..lineTo(size * 0.463, size * 0.595)
      ..lineTo(size * 0.655, size * 0.395),
    Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round,
  );
}

/// The tile behind the mark.
///
/// [rounded] only for previews. The shipped icon is a full opaque square: iOS
/// applies its own mask and a transparent corner shows as a dark notch under
/// it, and Android crops this away entirely for adaptive icons.
void _paintTile(
  Canvas canvas,
  double size,
  Color deep,
  Color bright, {
  required bool rounded,
}) {
  final rect = Rect.fromLTWH(0, 0, size, size);
  final paint = Paint()
    ..shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [deep, bright],
    ).createShader(rect);

  if (rounded) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(size * 0.225)),
      paint,
    );
  } else {
    canvas.drawRect(rect, paint);
  }

  // A soft highlight across the top left, so the tile reads as a surface rather
  // than a flat swatch. Barely visible alone; obvious by its absence.
  canvas.save();
  canvas.clipRRect(
    RRect.fromRectAndRadius(
      rect,
      Radius.circular(rounded ? size * 0.225 : 0),
    ),
  );
  canvas.drawCircle(
    Offset(size * 0.24, size * 0.18),
    size * 0.55,
    Paint()
      ..shader = ui.Gradient.radial(
        Offset(size * 0.24, size * 0.18),
        size * 0.55,
        [
          Colors.white.withValues(alpha: 0.16),
          Colors.white.withValues(alpha: 0),
        ],
      ),
  );
  canvas.restore();
}

Future<void> _write(
  String path,
  double size,
  void Function(Canvas) paint,
) async {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder, Rect.fromLTWH(0, 0, size, size)));

  final image = await recorder.endRecording().toImage(
    size.toInt(),
    size.toInt(),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());

  // ignore: avoid_print
  print('wrote $path');
}
