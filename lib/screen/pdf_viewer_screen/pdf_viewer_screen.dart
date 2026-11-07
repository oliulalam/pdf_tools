import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:share_plus/share_plus.dart';

class PdfViewerScreen extends StatefulWidget {
  final String path;
  final String title;

  const PdfViewerScreen({
    super.key,
    required this.path,
    required this.title,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  pdfx.PdfControllerPinch? _pdfController;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _initPdf();
  }

  void _initPdf() {
    try {
      if (File(widget.path).existsSync()) {
        _pdfController = pdfx.PdfControllerPinch(
          document: pdfx.PdfDocument.openFile(widget.path),
        );
      } else {
        _isError = true;
      }
    } catch (e) {
      _isError = true;
    }
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final file = File(widget.path);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: theme.appBarTheme.titleTextStyle,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: () {
              SharePlus.instance.share(ShareParams(files: [XFile(widget.path)]));
            },
          ),
        ],
      ),
      body: (!file.existsSync() || _isError)
          ? const Center(
              child: Text("File not found or unreadable."),
            )
          : (_pdfController != null
              ? pdfx.PdfViewPinch(
                  controller: _pdfController!,
                )
              : const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                )),
    );
  }
}
