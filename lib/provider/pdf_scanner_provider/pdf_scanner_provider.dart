import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:pdf_toolkit/provider/file_history_provider.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

class PdfScannerProvider extends ChangeNotifier {
  bool _isScanning = false;
  bool get isScanning => _isScanning;

  Future<bool> startScan(BuildContext context) async {
    _isScanning = true;
    notifyListeners();

    try {
      final DocumentScannerOptions options = DocumentScannerOptions(
        mode: ScannerMode.full,
        pageLimit: 100, // Maximum pages per scan
        isGalleryImport: true,
      );

      final documentScanner = DocumentScanner(options: options);
      
      final DocumentScanningResult result = await documentScanner.scanDocument();
      
      if (result.pdf != null && result.pdf!.uri.isNotEmpty) {
        // ML Kit returns a URI (file path).
        // Let's ask the user where to save it to permanently keep it.
        final String scannedPdfPath = result.pdf!.uri;
        final File tempFile = File(scannedPdfPath);
        
        if (await tempFile.exists()) {
          final String? outputPath = await FilePicker.saveFile(
            dialogTitle: 'Save Scanned PDF',
            fileName: 'Scanned_Doc_${DateTime.now().millisecondsSinceEpoch}.pdf',
            type: FileType.custom,
            allowedExtensions: ['pdf'],
            bytes: await tempFile.readAsBytes(),
          );

          if (outputPath != null && context.mounted) {
            context.read<FileHistoryProvider>().addFile(outputPath);
            _isScanning = false;
            notifyListeners();
            return true;
          }
        }
      }
      
      _isScanning = false;
      notifyListeners();
      return false;
      
    } catch (e) {
      debugPrint("Scanner Error: $e");
      _isScanning = false;
      notifyListeners();
      return false;
    }
  }
}
