import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf_toolkit/provider/file_history_provider.dart';
import 'package:provider/provider.dart';
import 'package:docx_dart/docx_dart.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart' as pdf_renderer;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class PdfToWordProvider extends ChangeNotifier {
  File? _selectedFile;
  bool _isLoading = false;
  String? _statusMessage;
  double _progress = 0.0;
  bool _isCancelled = false;

  // To hold extracted text for reviewing
  String? _extractedText;

  File? get selectedFile => _selectedFile;
  bool get isLoading => _isLoading;
  String? get statusMessage => _statusMessage;
  double get progress => _progress;
  String? get extractedText => _extractedText;

  Future<void> pickFile() async {
    final FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    final PlatformFile? pickedFile = result?.files.single;

    if (pickedFile != null && pickedFile.path != null) {
      _selectedFile = File(pickedFile.path!);
      _statusMessage = "Selected: ${pickedFile.name}";
      _progress = 0.0;
      _extractedText = null;
      notifyListeners();
    }
  }

  void cancel() {
    _isCancelled = true;
    _isLoading = false;
    _statusMessage = "Operation cancelled";
    notifyListeners();
  }

  Future<bool> extractTextForReview() async {
    if (_selectedFile == null) return false;

    _isLoading = true;
    _progress = 0.0;
    _isCancelled = false;
    _extractedText = null;
    _statusMessage = "Initializing OCR Engine...";
    notifyListeners();

    final textRecognizer = TextRecognizer(
      script: TextRecognitionScript.devanagiri,
    );
    pdf_renderer.PdfDocument? doc;
    StringBuffer extractedBuffer = StringBuffer();

    try {
      doc = await pdf_renderer.PdfDocument.openFile(_selectedFile!.path);
      final tempDir = await getTemporaryDirectory();
      final tempImagePath = "${tempDir.path}/ocr_temp_buffer.jpg";
      final imageFile = File(tempImagePath);

      for (int i = 1; i <= doc.pagesCount; i++) {
        if (_isCancelled) break;

        _statusMessage = "Reading Page $i of ${doc.pagesCount}...";
        _progress = i / doc.pagesCount;
        notifyListeners();

        final page = await doc.getPage(i);
        final pageImage = await page.render(
          width: page.width * 2,
          height: page.height * 2,
          format: pdf_renderer.PdfPageImageFormat.jpeg,
          quality: 90,
        );

        if (pageImage != null) {
          await imageFile.writeAsBytes(pageImage.bytes);
          final inputImage = InputImage.fromFilePath(tempImagePath);
          final RecognizedText recognizedText = await textRecognizer
              .processImage(inputImage);

          if (recognizedText.text.trim().isNotEmpty) {
            extractedBuffer.writeln(recognizedText.text);
            extractedBuffer.writeln(); // Add spacing between pages
          }
        }
        await page.close();
      }

      if (_isCancelled) {
        if (await imageFile.exists()) await imageFile.delete();
        return false;
      }

      _extractedText = extractedBuffer.toString();
      _isLoading = false;
      _statusMessage = "Extraction Complete. Review your text.";
      notifyListeners();

      if (await imageFile.exists()) await imageFile.delete();
      return true;
    } catch (e) {
      debugPrint("OCR Extraction Error: $e");
      _isLoading = false;
      if (e.toString().contains("optional module to be downloaded")) {
        _statusMessage =
            "গুগল সার্ভিস থেকে প্রয়োজনীয় রিসোর্স ডাউনলোড হচ্ছে। দয়া করে ১-২ মিনিট অপেক্ষা করে আবার চেষ্টা করুন।";
      } else {
        _statusMessage = "Error occurred during extraction";
      }
      notifyListeners();
      return false;
    } finally {
      await doc?.close();
      await textRecognizer.close();
    }
  }

  Future<bool> saveWordDocument(
    BuildContext context,
    String finalEditedText,
  ) async {
    _isLoading = true;
    _statusMessage = "Generating Word document...";
    notifyListeners();

    try {
      final tempDir = await getTemporaryDirectory();
      final tempFilePath =
          "${tempDir.path}/final_output_${DateTime.now().millisecondsSinceEpoch}.docx";

      // Offload to compute to prevent UI freeze
      await compute(
        _generateDocxTask,
        _DocxTaskParams(text: finalEditedText, tempPath: tempFilePath),
      );

      final File wordFile = File(tempFilePath);
      final Uint8List docxBytes = await wordFile.readAsBytes();

      final String? outputPath = await FilePicker.saveFile(
        dialogTitle: 'Save Word Document',
        fileName: 'OCR_Converted_${DateTime.now().millisecondsSinceEpoch}.docx',
        type: FileType.custom,
        allowedExtensions: ['docx'],
        bytes: docxBytes,
      );

      if (await wordFile.exists()) await wordFile.delete();

      if (outputPath == null) {
        _isLoading = false;
        _statusMessage = "Save cancelled";
        notifyListeners();
        return false;
      }

      _isLoading = false;
      _statusMessage = "✅ Successfully saved!";
      notifyListeners();

      if (context.mounted) {
        Provider.of<FileHistoryProvider>(
          context,
          listen: false,
        ).addFile(outputPath);
        await OpenFilex.open(outputPath);
      }
      return true;
    } catch (e) {
      debugPrint("Save DOCX Error: $e");
      _isLoading = false;
      _statusMessage = "Error saving file";
      notifyListeners();
      return false;
    }
  }

  void reset() {
    _selectedFile = null;
    _isLoading = false;
    _statusMessage = null;
    _progress = 0.0;
    _isCancelled = false;
    _extractedText = null;
    notifyListeners();
  }
}

class _DocxTaskParams {
  final String text;
  final String tempPath;
  _DocxTaskParams({required this.text, required this.tempPath});
}

void _generateDocxTask(_DocxTaskParams params) {
  final Document document = loadDocxDocument();
  final lines = params.text.split('\n');
  for (var line in lines) {
    if (line.trim().isNotEmpty) {
      document.addParagraph(text: line.trim());
    }
  }
  document.save(params.tempPath);
}
