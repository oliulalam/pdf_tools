import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdf_toolkit/provider/file_history_provider.dart';
import 'package:pdf_toolkit/utils/ad_helper.dart';
import 'package:pdf_toolkit/widgets/tool_ui_components.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:share_plus/share_plus.dart';

class ScannedDocumentPreviewScreen extends StatefulWidget {
  final String tempPdfPath;
  final int pageCount;

  const ScannedDocumentPreviewScreen({
    super.key,
    required this.tempPdfPath,
    this.pageCount = 1,
  });

  @override
  State<ScannedDocumentPreviewScreen> createState() =>
      _ScannedDocumentPreviewScreenState();
}

class _ScannedDocumentPreviewScreenState
    extends State<ScannedDocumentPreviewScreen> {
  final PdfViewerController _pdfViewerController = PdfViewerController();
  bool _isSaving = false;

  @override
  void dispose() {
    _pdfViewerController.dispose();
    super.dispose();
  }

  Future<void> _savePdf() async {
    final tempFile = File(widget.tempPdfPath);
    if (!tempFile.existsSync()) {
      Fluttertoast.showToast(
        msg: "Scanned file not found.",
        backgroundColor: Colors.red,
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final Uint8List bytes = await tempFile.readAsBytes();
      final defaultFileName =
          'Scanned_${DateTime.now().millisecondsSinceEpoch}.pdf';

      final String? outputPath = await FilePicker.saveFile(
        dialogTitle: 'Save Scanned PDF',
        fileName: defaultFileName,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: bytes,
      );

      if (outputPath != null && mounted) {
        // Save to Recent Files history
        await context
            .read<FileHistoryProvider>()
            .addFile(outputPath, bytes: bytes);

        Fluttertoast.showToast(msg: "PDF saved successfully!");

        // Show interstitial ad if ready, then open file and navigate back
        AdHelper.showInterstitialAd(() {
          if (mounted) {
            OpenFilex.open(outputPath);
            Navigator.pop(context, outputPath);
          }
        });
      } else {
        if (mounted) {
          setState(() => _isSaving = false);
        }
      }
    } catch (e) {
      debugPrint("Error saving scanned PDF: $e");
      if (mounted) {
        setState(() => _isSaving = false);
        Fluttertoast.showToast(
          msg: "Save failed: $e",
          backgroundColor: Colors.red,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final file = File(widget.tempPdfPath);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Scanned Document (${widget.pageCount} ${widget.pageCount > 1 ? 'pages' : 'page'})",
          style: theme.appBarTheme.titleTextStyle,
        ),
        actions: [
          IconButton(
            tooltip: "Share",
            icon: const Icon(Icons.share_rounded),
            onPressed: () {
              if (file.existsSync()) {
                SharePlus.instance.share(
                  ShareParams(files: [XFile(widget.tempPdfPath)]),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: file.existsSync()
                ? SfPdfViewer.file(
                    file,
                    controller: _pdfViewerController,
                    canShowScrollHead: false,
                    canShowScrollStatus: true,
                    onDocumentLoadFailed: (details) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Failed to load PDF: ${details.error}"),
                          ),
                        );
                      }
                    },
                  )
                : const Center(
                    child: Text("Scanned file not found or corrupted."),
                  ),
          ),
          BottomActionBar(
            actionText: "Save PDF",
            isLoading: _isSaving,
            color: Colors.blueAccent,
            onAction: _savePdf,
          ),
        ],
      ),
    );
  }
}
