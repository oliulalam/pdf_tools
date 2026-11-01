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
        mode: ScannerMode.filter, // Base mode (allows crop & filter). ML Kit controls auto-capture internally.
        pageLimit: 100,
        isGalleryImport: true,
      );

      final documentScanner = DocumentScanner(options: options);
      
      final DocumentScanningResult result = await documentScanner.scanDocument();
      
      if (result.pdf != null && result.pdf!.uri.isNotEmpty) {
        final String scannedPdfPath = result.pdf!.uri;
        final File tempFile = File(scannedPdfPath);
        
        if (await tempFile.exists()) {
          final bytes = await tempFile.readAsBytes();
          
          String? permanentPath;
          if (context.mounted) {
            permanentPath = await context.read<FileHistoryProvider>().addFile(
              'Scanned_Doc_${DateTime.now().millisecondsSinceEpoch}.pdf',
              bytes: bytes,
            );
          }

          _isScanning = false;
          notifyListeners();
          return permanentPath;
        }
      }
      
      _isScanning = false;
      notifyListeners();
      return null;
      
    } catch (e) {
      debugPrint("Scanner Error: $e");
      _isScanning = false;
      notifyListeners();
      return null;
    }
  }
}
