import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_toolkit/provider/file_history_provider.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

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
        mode: ScannerMode.filter, // Manual capture mode (no auto-capture), supports crop, filter & page reorder
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
          
          // Save a copy permanently into App Documents directory so it is NEVER deleted by cache cleaners
          final appDir = await getApplicationDocumentsDirectory();
          final docsDir = Directory('${appDir.path}/PDF_Quant_Documents');
          if (!await docsDir.exists()) {
            await docsDir.create(recursive: true);
          }
          final fileName = 'Scanned_Doc_${DateTime.now().millisecondsSinceEpoch}.pdf';
          final permanentPath = '${docsDir.path}/$fileName';
          final permanentFile = File(permanentPath);
          await permanentFile.writeAsBytes(bytes);

          // Add to FileHistoryProvider so it shows in Recent Documents
          if (context.mounted) {
            context.read<FileHistoryProvider>().addFile(permanentPath);
          }

          // Offer optional FilePicker export
          try {
            final String? userExportPath = await FilePicker.saveFile(
              dialogTitle: 'Save Scanned PDF',
              fileName: fileName,
              type: FileType.custom,
              allowedExtensions: ['pdf'],
              bytes: bytes,
            );
            if (userExportPath != null && context.mounted) {
              context.read<FileHistoryProvider>().addFile(userExportPath);
              _isScanning = false;
              notifyListeners();
              return userExportPath;
            }
          } catch (e) {
            debugPrint("Optional export skipped: $e");
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
