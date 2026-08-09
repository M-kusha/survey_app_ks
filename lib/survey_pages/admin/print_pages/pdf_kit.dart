import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

abstract final class PdfKit {
  static const ink = PdfColors.blueGrey900;
  static const muted = PdfColors.blueGrey400;
  static const rule = PdfColors.blueGrey100;
  static const correct = PdfColors.green700;
  static const wrong = PdfColors.red700;
  static const chosen = PdfColors.blue700;

  static const correctFill = PdfColors.green50;
  static const wrongFill = PdfColors.red50;

  static pw.ThemeData? _theme;

  static Future<pw.ThemeData> theme() async {
    if (_theme case final theme?) return theme;

    Future<pw.Font> load(String name) async =>
        pw.Font.ttf(await rootBundle.load('assets/fonts/$name.ttf'));

    return _theme = pw.ThemeData.withFont(
      base: await load('Inter-Regular'),
      bold: await load('Inter-Bold'),
      italic: await load('Inter-Regular'),
      boldItalic: await load('Inter-Bold'),
    );
  }

  static pw.Widget header({required String title, required String subtitle}) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      margin: const pw.EdgeInsets.only(bottom: 16),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: rule, width: 1)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  title,
                  maxLines: 2,
                  style: pw.TextStyle(
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                    color: ink,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  subtitle,
                  style: const pw.TextStyle(fontSize: 9, color: muted),
                ),
              ],
            ),
          ),
          pw.Text(
            'app_title'.tr(),
            style: const pw.TextStyle(fontSize: 9, color: muted),
          ),
        ],
      ),
    );
  }

  static pw.Widget footer(pw.Context context) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 8),
    child: pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text(
        '${context.pageNumber} / ${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 8, color: muted),
      ),
    ),
  );

  static pw.Widget stat(String label, String value, {PdfColor tint = ink}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label.toUpperCase(),
          style: const pw.TextStyle(fontSize: 7, color: muted),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: tint,
          ),
        ),
      ],
    );
  }

  static pw.Widget summary(List<pw.Widget> stats) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    margin: const pw.EdgeInsets.only(bottom: 16),
    decoration: pw.BoxDecoration(
      color: PdfColors.blueGrey50,
      borderRadius: pw.BorderRadius.circular(6),
    ),
    child: pw.Row(
      children: [for (final stat in stats) pw.Expanded(child: stat)],
    ),
  );

  static pw.Widget questionHeading(int number, String question) => pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(
        width: 22,
        child: pw.Text(
          '$number.',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: muted,
          ),
        ),
      ),
      pw.Expanded(
        child: pw.Text(
          question,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: ink,
          ),
        ),
      ),
    ],
  );

  static pw.Widget bar(double fraction, {PdfColor fill = chosen}) {
    final filled = (fraction.clamp(0.0, 1.0) * _barSteps).round();

    return pw.Container(
      height: 6,
      decoration: pw.BoxDecoration(
        color: rule,
        borderRadius: pw.BorderRadius.circular(3),
      ),

      child: pw.Row(
        children: [
          if (filled > 0)
            pw.Expanded(
              flex: filled,
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  color: fill,
                  borderRadius: pw.BorderRadius.circular(3),
                ),
              ),
            ),
          if (filled < _barSteps)
            pw.Expanded(flex: _barSteps - filled, child: pw.SizedBox()),
        ],
      ),
    );
  }

  static const _barSteps = 1000;

  static pw.Widget row({
    required String text,
    required String? tag,
    PdfColor chipColor = rule,
    PdfColor? fill,
    bool picked = false,
    bool lostMark = false,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 4),
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: pw.BoxDecoration(
        color: fill,
        borderRadius: pw.BorderRadius.circular(4),

        border: pw.Border.all(
          color: lostMark
              ? wrong
              : picked
              ? chipColor
              : rule,
          width: picked || lostMark ? 1.4 : 0.5,
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: picked ? 10 : 8,
            height: picked ? 10 : 8,
            margin: const pw.EdgeInsets.only(top: 2, right: 8),
            decoration: pw.BoxDecoration(
              color: picked ? chipColor : PdfColors.white,
              border: pw.Border.all(color: chipColor, width: 1),
              borderRadius: pw.BorderRadius.circular(2),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              text,
              style: pw.TextStyle(
                fontSize: 10,
                color: ink,
                fontWeight: picked ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
          if (tag != null) ...[
            pw.SizedBox(width: 8),

            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 2,
              ),
              decoration: pw.BoxDecoration(
                color: chipColor == rule ? PdfColors.white : chipColor,
                borderRadius: pw.BorderRadius.circular(3),
                border: pw.Border.all(color: chipColor, width: 0.8),
              ),
              child: pw.Text(
                tag.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                  color: chipColor == rule ? muted : PdfColors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
