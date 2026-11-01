import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:pdf_toolkit/provider/file_history_provider.dart';
import 'package:provider/provider.dart';

class PdfScannerProvider extends ChangeNotifier {
  bool _isScanning = false;
  bool get isScanning => _isScanning;

  Future<String?> startScan(BuildContext context) async {
    return _performScan(context);
  }

  Future<String?> _performScan(BuildContext context) async {
    _isScanning = true;
    notifyListeners();

    try {
      final DocumentScannerOptions options = DocumentScannerOptions(
        documentFormats: {DocumentFormat.pdf}, // v0.5.0: plural name, takes a Set
        mode: ScannerMode.filter, // crop & filter. ML Kit controls auto-capture internally.
        pageLimit: 100,
        isGalleryImport: true,
      );

      final documentScanner = DocumentScanner(options: options);

      final DocumentScanningResult result = await documentScanner.scanDocument();
      debugPrint(
        "Scanner result -> pdf: ${result.pdf?.uri}, "
            "pageCount: ${result.pdf?.pageCount}, images: ${result.images?.length ?? 0}",
      );

      if (result.pdf != null && result.pdf!.uri.isNotEmpty) {
        final File tempFile = File(result.pdf!.uri);

        if (await tempFile.exists()) {
          final bytes = await tempFile.readAsBytes();

          if (!context.mounted) return null;

          // Saves a private copy and adds it to Recent Documents.
          final String? permanentPath =
          await context.read<FileHistoryProvider>().addFile(
            'Scanned_Doc_${DateTime.now().millisecondsSinceEpoch}.pdf',
            bytes: bytes,
          );

          return permanentPath;
        } else {
          debugPrint("Scanner: PDF file not found at ${result.pdf!.uri}");
        }
      }

      return null;
    } catch (e, st) {
      debugPrint("Scanner Error: ${e.runtimeType} $e\n$st");
      return null;
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }
}