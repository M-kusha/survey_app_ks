import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/widgets/feature_kit.dart';
import 'package:echomeet/utilities/reusable_widgets.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfViewerPage extends StatefulWidget {
  const PdfViewerPage({
    super.key,
    required this.title,
    required this.fileName,
    required this.build,
  });

  final String title;

  final String fileName;

  final Future<pw.Document> Function(PdfPageFormat format) build;

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  static const _format = PdfPageFormat.a4;

  Uint8List? _bytes;
  String? _error;

  String get _fileName => '${widget.fileName}.pdf';

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    setState(() => _error = null);

    try {
      final document = await widget.build(_format);
      final bytes = await document.save();
      if (!mounted) return;
      setState(() => _bytes = bytes);
    } catch (e) {
      if (!mounted) return;

      setState(() => _error = '$e');
    }
  }

  void _print() {
    final bytes = _bytes;
    if (bytes == null) return;

    Printing.layoutPdf(
      onLayout: (_) => bytes,
      name: _fileName,
    ).catchError(_report);
  }

  void _download() {
    final bytes = _bytes;
    if (bytes == null) return;

    Printing.sharePdf(bytes: bytes, filename: _fileName).catchError(_report);
  }

  bool _report(Object error, StackTrace _) {
    if (mounted) UIUtils.showSnackBar(context, 'error_occurred'.tr());
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    final ready = bytes != null && _error == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'print'.tr(),
            onPressed: ready ? _print : null,
            icon: const Icon(Icons.print_outlined),
          ),
          IconButton(
            tooltip: 'download'.tr(),
            onPressed: ready ? _download : null,
            icon: const Icon(Icons.download_rounded),
          ),
          const SizedBox(width: Spacing.xs),
        ],
      ),
      body: SafeArea(
        child: switch ((_error, bytes)) {
          (final error?, _) => EmptyState(
            icon: Icons.picture_as_pdf_outlined,
            title: 'pdf_failed'.tr(),
            body: error,
            action: TextButton(onPressed: _generate, child: Text('retry'.tr())),
          ),
          (_, final bytes?) => PdfPreview(
            build: (_) => bytes,
            pdfFileName: _fileName,

            useActions: false,
            canChangePageFormat: false,
            canChangeOrientation: false,
            canDebug: false,

            onError: (context, error) => EmptyState(
              icon: Icons.picture_as_pdf_outlined,
              title: 'pdf_ready'.tr(),
              body: 'pdf_preview_unavailable'.tr(),
            ),
          ),
          _ => const Center(
            child: Padding(
              padding: EdgeInsets.all(Spacing.xxl),
              child: CircularProgressIndicator(),
            ),
          ),
        },
      ),
    );
  }
}

String pdfFileNameFrom(List<String> parts) {
  final cleaned = parts
      .map(
        (part) => part
            .trim()
            .replaceAll(RegExp(r'[^\w\s-]'), '')
            .replaceAll(RegExp(r'\s+'), '-'),
      )
      .where((part) => part.isNotEmpty)
      .join('-');

  if (cleaned.isEmpty) return 'echomeet-export';

  return cleaned.length <= 80 ? cleaned : cleaned.substring(0, 80);
}
