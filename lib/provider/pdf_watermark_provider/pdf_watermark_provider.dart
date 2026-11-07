import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
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
      final pickedFile = result?.files.single;
      if (pickedFile != null) {
        if (pickedFile.path != null && pickedFile.path!.isNotEmpty) {
          final f = File(pickedFile.path!);
          if (await f.exists()) {
            _selectedFile = f;
            notifyListeners();
            return;
          }
        }
        try {
          final bytes = await pickedFile.xFile.readAsBytes();
          if (bytes.isNotEmpty) {
            final tempDir = await getTemporaryDirectory();
            final tempFile = File('${tempDir.path}/temp_wm_${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}');
            await tempFile.writeAsBytes(bytes);
            _selectedFile = tempFile;
            notifyListeners();
          }
        } catch (e) {
          debugPrint("Error reading bytes for watermark: $e");
        }
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

      final Uint8List sourceBytes = await _selectedFile!.readAsBytes();
      if (sourceBytes.length < 5 || String.fromCharCodes(sourceBytes.take(5)) != '%PDF-') {
        throw const FormatException('The selected file is not a valid PDF.');
      }

      final bytes = await _watermarkTask(
        _WatermarkParams(
          inputBytes: sourceBytes,
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
        await context.read<FileHistoryProvider>().addFile(outputPath, bytes: bytes);
        return true;
      }
      return false;
    } catch (e, stackTrace) {
      debugPrint("Watermark Task Error: $e");
      debugPrintStack(stackTrace: stackTrace);
      _isLoading = false;
      _statusMessage = "Error occurred.";
      notifyListeners();
      
      if (context.mounted) {
        String msg = 'Could not edit this PDF: $e';
        final errorText = e.toString().toLowerCase();
        if (errorText.contains('password') || errorText.contains('encrypt')) {
          msg = 'Failed: Please unlock the PDF before adding a watermark.';
        } else if (e is FormatException) {
          msg = e.message;
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
  final Uint8List inputBytes;
  final bool addWatermark;
  final String watermarkText;
  final bool addPageNumbers;
  final Uint8List fontData;
  const _WatermarkParams({
    required this.inputBytes,
    required this.addWatermark,
    required this.watermarkText,
    required this.addPageNumbers,
    required this.fontData,
  });
}

PdfFont _createWatermarkFont(Uint8List fontData, String text, double fontSize) {
  // Check if text contains non-ASCII characters (e.g. Bengali unicode)
  final bool hasNonAscii = text.codeUnits.any((unit) => unit > 127);
  if (hasNonAscii) {
    try {
      return PdfTrueTypeFont(fontData, fontSize);
    } catch (e) {
      debugPrint('Error loading TrueType font: $e');
    }
  }
  return PdfStandardFont(PdfFontFamily.helvetica, fontSize, style: PdfFontStyle.bold);
}

Future<Uint8List> _watermarkTask(_WatermarkParams params) async {
  final document = PdfDocument(inputBytes: params.inputBytes);
  try {
    final pageNumberFont = PdfStandardFont(PdfFontFamily.helvetica, 12);
    final centerFormat = PdfStringFormat(
      alignment: PdfTextAlignment.center,
      lineAlignment: PdfVerticalAlignment.middle,
    );

    for (int i = 0; i < document.pages.count; i++) {
      final page = document.pages[i];
      final size = page.size;
      final g = page.graphics;
      debugPrint('Page ${i + 1}: ${size.width} x ${size.height}');

      if (params.addWatermark && params.watermarkText.trim().isNotEmpty) {
        final text = params.watermarkText.trim();
        final font = _createWatermarkFont(params.fontData, text, 48);
        final state = g.save();
        g.setTransparency(0.35);
        g.translateTransform(size.width / 2, size.height / 2);
        g.rotateTransform(-45);

        final textSize = font.measureString(text);
        g.drawString(
          text,
          font,
          brush: PdfBrushes.red,
          bounds: Rect.fromLTWH(
            -size.width / 2,
            -textSize.height,
            size.width,
            textSize.height * 2,
          ),
          format: centerFormat,
        );
        g.restore(state);
      }

      if (params.addPageNumbers) {
        final state = g.save();
        g.drawString(
          '${i + 1} / ${document.pages.count}',
          pageNumberFont,
          brush: PdfBrushes.black,
          bounds: Rect.fromLTWH(0, size.height - 36, size.width, 24),
          format: centerFormat,
        );
        g.restore(state);
      }
    }

    final outBytes = await document.save();
    return Uint8List.fromList(outBytes);
  } finally {
    document.dispose();
  }
}
