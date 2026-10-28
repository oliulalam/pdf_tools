import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
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
  final PdfViewerController _pdfViewerController = PdfViewerController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final file = File(widget.path);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.title, style: theme.appBarTheme.titleTextStyle),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: () {
              SharePlus.instance.share(ShareParams(files: [XFile(widget.path)]));
            },
          ),
        ],
      ),
      body: file.existsSync()
          ? SfPdfViewer.file(
              file,
              controller: _pdfViewerController,
              canShowScrollHead: false,
              canShowScrollStatus: true,
            )
          : const Center(
              child: Text("File not found or deleted."),
            ),
    );
  }
}
