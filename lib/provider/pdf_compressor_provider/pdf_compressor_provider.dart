import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart'; // For compute
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_toolkit/provider/file_history_provider.dart';
import 'package:provider/provider.dart';
import 'package:pdfx/pdfx.dart' as renderer;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:open_filex/open_filex.dart';

class PdfCompressorProvider extends ChangeNotifier {
  File? _selectedFile;
  int _originalFileSize = 0;
  bool _isLoading = false;
  String? _statusMessage;
  double _quality = 0.5;

  File? get selectedFile => _selectedFile;
  bool get isLoading => _isLoading;
  String? get statusMessage => _statusMessage;
  double get quality => _quality;

  void setQuality(double value) {
    _quality = value;
    notifyListeners();
  }

  Future<void> pickFile() async {
    final FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    final PlatformFile? pickedFile = result?.files.single;

    if (pickedFile != null && pickedFile.path != null) {
      _selectedFile = File(pickedFile.path!);
      _originalFileSize = await _selectedFile!.length();
      final double sizeMB = _originalFileSize / (1024 * 1024);
      _statusMessage = "Original Size: ${sizeMB.toStringAsFixed(2)} MB";
      notifyListeners();
    }
  }

  Future<bool> compressAndSave(BuildContext context) async {
    if (_selectedFile == null) return false;

    _isLoading = true;
    _statusMessage = "Preparing to compress...";
    notifyListeners();

    Directory? tempDir;
    try {
      final String inputPath = _selectedFile!.path;
      final double qualityValue = _quality;

      final document = await renderer.PdfDocument.openFile(inputPath);
      final List<String> tempImagePaths = [];

      // Create a unique temporary directory for this session
      final appTempDir = await getTemporaryDirectory();
      tempDir = Directory(
        '${appTempDir.path}/compress_${DateTime.now().millisecondsSinceEpoch}',
      );
      await tempDir.create(recursive: true);

      for (int i = 1; i <= document.pagesCount; i++) {
        _statusMessage = "Processing Page $i of ${document.pagesCount}...";
        notifyListeners();

        final page = await document.getPage(i);

        // Optimization for aggressive compression mapping correctly to UI toggles
        final double scale = qualityValue <= 0.3
            ? 1.0   // Smallest file (20%)
            : (qualityValue <= 0.5 ? 1.5 : 2.0); // Recommended (50%) or Smaller file (80%)

        final img = await page.render(
          width: page.width * scale,
          height: page.height * scale,
          format: renderer.PdfPageImageFormat.jpeg,
          quality: (qualityValue * 100).toInt().clamp(10, 100),
        );

        if (img != null) {
          final String path = '${tempDir.path}/page_$i.jpg';
          await File(path).writeAsBytes(img.bytes);
          tempImagePaths.add(path);
        }
        await page.close();
      }
      await document.close();

      if (tempImagePaths.isEmpty) throw Exception("Failed to render PDF pages");

      _statusMessage = "Reconstructing PDF (RAM Safe)...";
      notifyListeners();

      // Use compute with top-level function to avoid captures
      final Uint8List compressedBytes = await compute(
        reconstructPdfFromDiskTask,
        tempImagePaths,
      );

      _statusMessage = "Saving compressed file...";
      notifyListeners();

      // Check if compressed file is actually larger than original
      final Uint8List finalBytes;
      bool keptOriginal = false;
      if (compressedBytes.lengthInBytes >= _originalFileSize) {
        finalBytes = await _selectedFile!.readAsBytes();
        keptOriginal = true;
        _statusMessage = "⚠️ Target file is too small or couldn't be compressed. Saving original.";
        notifyListeners();
      } else {
        finalBytes = compressedBytes;
      }

      final String? outputPath = await FilePicker.saveFile(
        dialogTitle: 'Select Save Location',
        fileName: 'Compressed_${DateTime.now().millisecondsSinceEpoch}.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: finalBytes,
      );

      if (outputPath == null) {
        _isLoading = false;
        _statusMessage = "Save cancelled";
        notifyListeners();
        return false;
      }

      _isLoading = false;
      final double finalSizeMB = finalBytes.lengthInBytes / (1024 * 1024);
      if (keptOriginal) {
        _statusMessage = "⚠️ Kept original file (Text may not be selectable). Size: ${finalSizeMB.toStringAsFixed(2)} MB";
      } else {
        _statusMessage = "✅ Success! Compressed Size: ${finalSizeMB.toStringAsFixed(2)} MB (Text may not be selectable)";
      }
      notifyListeners();

      if (context.mounted) {
        context.read<FileHistoryProvider>().addFile(outputPath);
        await OpenFilex.open(outputPath);
      }
      return true;
    } catch (e) {
      debugPrint("Compression Error: $e");
      _isLoading = false;
      _statusMessage = "Error: $e";
      notifyListeners();
      return false;
    } finally {
      // Cleanup: Delete temporary session images
      if (tempDir != null && await tempDir.exists()) {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      }
    }
  }

  void reset() {
    _selectedFile = null;
    _isLoading = false;
    _statusMessage = null;
    _quality = 0.5;
    notifyListeners();
  }
}

/// Top-level function for reconstructing PDF from images
Future<Uint8List> reconstructPdfFromDiskTask(List<String> imagePaths) async {
  final pdf = pw.Document(compress: true);
  for (var path in imagePaths) {
    final imgBytes = File(path).readAsBytesSync();
    final image = pw.MemoryImage(imgBytes);
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (pw.Context context) =>
            pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
      ),
    );
  }
  return await pdf.save();
}
