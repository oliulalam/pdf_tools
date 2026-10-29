import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf_toolkit/provider/file_history_provider.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfWatermarkProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _statusMessage;
  File? _selectedFile;

  bool _addWatermark = true;
  bool _addPageNumbers = false;
  String _watermarkText = "CONFIDENTIAL";

  bool get isLoading => _isLoading;
  String? get statusMessage => _statusMessage;
  File? get selectedFile => _selectedFile;
  bool get addWatermark => _addWatermark;
  bool get addPageNumbers => _addPageNumbers;
  String get watermarkText => _watermarkText;

  void setWatermark(bool value) {
    _addWatermark = value;
    notifyListeners();
  }

  void setPageNumbers(bool value) {
    _addPageNumbers = value;
    notifyListeners();
  }

  void setWatermarkText(String text) {
    _watermarkText = text;
    notifyListeners();
  }

  Future<void> pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result != null && result.files.single.path != null) {
        _selectedFile = File(result.files.single.path!);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error picking file: $e");
    }
  }

  void reset() {
    _selectedFile = null;
    _isLoading = false;
    _statusMessage = null;
    _addWatermark = true;
    _addPageNumbers = false;
    _watermarkText = "CONFIDENTIAL";
    notifyListeners();
  }

  Future<bool> processAndSave(BuildContext context) async {
    if (_selectedFile == null) return false;
    if (!_addWatermark && !_addPageNumbers) return false;

    _isLoading = true;
    _statusMessage = "Processing PDF...";
    notifyListeners();

    try {
      // Load the Bengali font bytes from assets to pass to the isolate
      final ByteData fontByteData = await rootBundle.load('assets/fonts/NotoSansBengali-Regular.ttf');
      final Uint8List fontUint8List = fontByteData.buffer.asUint8List();

      final bytes = await compute(
        _watermarkTask,
        _WatermarkParams(
          inputPath: _selectedFile!.path,
          addWatermark: _addWatermark,
          watermarkText: _watermarkText,
          addPageNumbers: _addPageNumbers,
          fontData: fontUint8List,
        ),
      );

      final String? outputPath = await FilePicker.saveFile(
        dialogTitle: 'Save PDF',
        fileName: 'Watermarked_${DateTime.now().millisecondsSinceEpoch}.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: bytes,
      );

      _isLoading = false;
      _statusMessage = outputPath != null ? "Saved successfully!" : null;
      notifyListeners();

      if (outputPath != null && context.mounted) {
        context.read<FileHistoryProvider>().addFile(outputPath);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Watermark Task Error: $e");
      _isLoading = false;
      _statusMessage = "Error occurred.";
      notifyListeners();
      
      if (context.mounted) {
        String msg = 'Failed to apply watermark.';
        if (e.toString().toLowerCase().contains('password') || e.toString().toLowerCase().contains('encrypt')) {
          msg = 'Failed: Please unlock the PDF before adding a watermark.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
      return false;
    }
  }
}

class _WatermarkParams {
  final String inputPath;
  final bool addWatermark;
  final String watermarkText;
  final bool addPageNumbers;
  final Uint8List fontData;
  const _WatermarkParams({
    required this.inputPath,
    required this.addWatermark,
    required this.watermarkText,
    required this.addPageNumbers,
    required this.fontData,
  });
}

Future<Uint8List> _watermarkTask(_WatermarkParams params) async {
  final bytes = File(params.inputPath).readAsBytesSync();
  final document = PdfDocument(inputBytes: bytes);
  
  // Use TrueType font to support Bengali and other Unicode characters
  final font = PdfTrueTypeFont(params.fontData, 40);
  final smallFont = PdfTrueTypeFont(params.fontData, 12);

  for (int i = 0; i < document.pages.count; i++) {
    final page = document.pages[i];
    final size = page.size;

    if (params.addWatermark && params.watermarkText.isNotEmpty) {
      final graphics = page.graphics;
      graphics.save();
      graphics.setTransparency(0.25);
      
      // Center the watermark and rotate it diagonally
      graphics.translateTransform(size.width / 2, size.height / 2);
      graphics.rotateTransform(-45);
      
      final textSize = font.measureString(params.watermarkText);
      graphics.drawString(
        params.watermarkText,
        font,
        brush: PdfBrushes.red,
        bounds: Rect.fromLTWH(-textSize.width / 2, -textSize.height / 2, textSize.width, textSize.height),
      );
      graphics.restore();
    }

    if (params.addPageNumbers) {
      final text = "${i + 1} / ${document.pages.count}";
      final textSize = smallFont.measureString(text);
      page.graphics.drawString(
        text,
        smallFont,
        brush: PdfBrushes.black,
        bounds: Rect.fromLTWH((size.width - textSize.width) / 2, size.height - 30, textSize.width, textSize.height),
      );
    }
  }

  final outBytes = await document.save();
  document.dispose();
  return Uint8List.fromList(outBytes);
}
