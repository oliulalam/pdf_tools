import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf_toolkit/provider/file_history_provider.dart';
import 'package:provider/provider.dart';
import 'package:archive/archive.dart';
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

  Future<bool> extractAndSave(BuildContext context) async {
    if (_selectedFile == null) return false;

    _isLoading = true;
    _progress = 0.0;
    _isCancelled = false;
    _statusMessage = "Initializing OCR Engine...";
    notifyListeners();

    // Use latin script as default to support English optimally
    final textRecognizer = TextRecognizer(
      script: TextRecognitionScript.latin,
    );
    pdf_renderer.PdfDocument? doc;
    StringBuffer extractedBuffer = StringBuffer();

    try {
      doc = await pdf_renderer.PdfDocument.openData(await _selectedFile!.readAsBytes());
      final tempDir = await getTemporaryDirectory();
      final tempImagePath = "${tempDir.path}/ocr_temp_buffer.jpg";
      final imageFile = File(tempImagePath);

      for (int i = 1; i <= doc.pagesCount; i++) {
        if (_isCancelled) break;
        _statusMessage = "Reading Page $i of ${doc.pagesCount}...";
        _progress = i / doc.pagesCount;
        notifyListeners();

        final page = await doc.getPage(i);

        try {
          // Dynamic scale based on width, clamped to prevent OOM
          final double scale = (2048 / page.width).clamp(2.0, 4.0);
          final pageImage = await page.render(
            width: page.width * scale,
            height: page.height * scale,
            format: pdf_renderer.PdfPageImageFormat.jpeg,
            quality: 90,
          );

          if (pageImage != null) {
            await imageFile.writeAsBytes(pageImage.bytes);
            final inputImage = InputImage.fromFilePath(tempImagePath);
            final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
            if (recognizedText.text.trim().isNotEmpty) {
              extractedBuffer.writeln(recognizedText.text);
              extractedBuffer.writeln(); // Add spacing between pages
            }
          }
        } catch (e) {
          debugPrint("Error processing page $i: $e");
        } finally {
          await page.close();
        }
      }

      if (_isCancelled) {
        if (await imageFile.exists()) await imageFile.delete();
        return false;
      }
      if (await imageFile.exists()) await imageFile.delete();

      final String finalEditedText = extractedBuffer.toString().trim();
      if (finalEditedText.isEmpty) {
        _isLoading = false;
        _statusMessage = "No text could be recognized in the document.";
        notifyListeners();
        return false;
      }

      _statusMessage = "Generating Word document...";
      notifyListeners();

      // Run Document creation on a background isolate
      final Uint8List docxBytes = await compute(_generateDocxTask, finalEditedText);

      // Save directly to application documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final String finalFilePath =
          "${appDir.path}/OCR_Converted_${DateTime.now().millisecondsSinceEpoch}.docx";

      final File wordFile = File(finalFilePath);
      await wordFile.writeAsBytes(docxBytes);

      _isLoading = false;
      _statusMessage = "✅ Successfully saved!";
      notifyListeners();

      if (context.mounted) {
        await Provider.of<FileHistoryProvider>(context, listen: false)
            .addFile(finalFilePath, bytes: docxBytes);
        await OpenFilex.open(finalFilePath);
      }
      return true;

    } catch (e) {
      debugPrint("OCR/Save DOCX Error: $e");
      _isLoading = false;
      if (e.toString().contains("optional module to be downloaded")) {
        _statusMessage = "গুগল সার্ভিস থেকে প্রয়োজনীয় রিসোর্স ডাউনলোড হচ্ছে। দয়া করে ১-২ মিনিট অপেক্ষা করে আবার চেষ্টা করুন।";
      } else {
        _statusMessage = "Error occurred: $e";
      }
      notifyListeners();
      return false;
    } finally {
      await doc?.close();
      await textRecognizer.close();
    }
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
      script: TextRecognitionScript.latin,
    );
    pdf_renderer.PdfDocument? doc;
    StringBuffer extractedBuffer = StringBuffer();

    try {
      doc = await pdf_renderer.PdfDocument.openData(await _selectedFile!.readAsBytes());
      final tempDir = await getTemporaryDirectory();
      final tempImagePath = "${tempDir.path}/ocr_temp_buffer.jpg";
      final imageFile = File(tempImagePath);

      for (int i = 1; i <= doc.pagesCount; i++) {
        if (_isCancelled) break;
        _statusMessage = "Reading Page $i of ${doc.pagesCount}...";
        _progress = i / doc.pagesCount;
        notifyListeners();

        final page = await doc.getPage(i);

        try {
          final double scale = (2048 / page.width).clamp(2.0, 4.0);
          final pageImage = await page.render(
            width: page.width * scale,
            height: page.height * scale,
            format: pdf_renderer.PdfPageImageFormat.jpeg,
            quality: 90,
          );

          if (pageImage != null) {
            await imageFile.writeAsBytes(pageImage.bytes);
            final inputImage = InputImage.fromFilePath(tempImagePath);
            final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
            if (recognizedText.text.trim().isNotEmpty) {
              extractedBuffer.writeln(recognizedText.text);
              extractedBuffer.writeln();
            }
          }
        } catch (e) {
          debugPrint("Error processing page $i: $e");
        } finally {
          await page.close();
        }
      }

      if (_isCancelled) {
        if (await imageFile.exists()) await imageFile.delete();
        return false;
      }

      _extractedText = extractedBuffer.toString().trim();
      _isLoading = false;
      
      if (_extractedText!.isEmpty) {
        _statusMessage = "No text could be recognized in the document.";
      } else {
        _statusMessage = "Extraction Complete. Review your text.";
      }
      notifyListeners();

      if (await imageFile.exists()) await imageFile.delete();
      return true;
    } catch (e) {
      debugPrint("OCR Extraction Error: $e");
      _isLoading = false;
      if (e.toString().contains("optional module to be downloaded")) {
        _statusMessage = "গুগল সার্ভিস থেকে প্রয়োজনীয় রিসোর্স ডাউনলোড হচ্ছে। দয়া করে ১-২ মিনিট অপেক্ষা করে আবার চেষ্টা করুন।";
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
      final Uint8List docxBytes = await compute(_generateDocxTask, finalEditedText);

      final appDir = await getApplicationDocumentsDirectory();
      final String finalFilePath =
          "${appDir.path}/OCR_Converted_${DateTime.now().millisecondsSinceEpoch}.docx";

      final File wordFile = File(finalFilePath);
      await wordFile.writeAsBytes(docxBytes);

      _isLoading = false;
      _statusMessage = "✅ Successfully saved!";
      notifyListeners();

      if (context.mounted) {
        await Provider.of<FileHistoryProvider>(
          context,
          listen: false,
        ).addFile(finalFilePath, bytes: docxBytes);
        await OpenFilex.open(finalFilePath);
      }
      return true;
    } catch (e) {
      debugPrint("Save DOCX Error: $e");
      _isLoading = false;
      _statusMessage = "Error saving file: $e";
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

Uint8List _generateDocxTask(String text) {
  final buffer = StringBuffer();
  buffer.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
  buffer.write('<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">');
  buffer.write('<w:body>');

  final lines = text.split('\n');
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isNotEmpty) {
      final sanitized = _escapeXml(trimmed);
      buffer.write('<w:p><w:r><w:t xml:space="preserve">$sanitized</w:t></w:r></w:p>');
    }
  }

  buffer.write('</w:body></w:document>');

  final archive = Archive();
  archive.addFile(ArchiveFile.string(
    '[Content_Types].xml',
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
    '<Default Extension="xml" ContentType="application/xml"/>'
    '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
    '</Types>',
  ));

  archive.addFile(ArchiveFile.string(
    '_rels/.rels',
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
    '</Relationships>',
  ));

  archive.addFile(ArchiveFile.string(
    'word/document.xml',
    buffer.toString(),
  ));

  final encoded = ZipEncoder().encode(archive);
  return Uint8List.fromList(encoded);
}

String _escapeXml(String text) {
  final sb = StringBuffer();
  for (final rune in text.runes) {
    if (rune == 0x9 ||
        rune == 0xA ||
        rune == 0xD ||
        (rune >= 0x20 && rune <= 0xD7FF) ||
        (rune >= 0xE000 && rune <= 0xFFFD) ||
        (rune >= 0x10000 && rune <= 0x10FFFF)) {
      switch (rune) {
        case 38: // &
          sb.write('&amp;');
          break;
        case 60: // <
          sb.write('&lt;');
          break;
        case 62: // >
          sb.write('&gt;');
          break;
        case 34: // "
          sb.write('&quot;');
          break;
        case 39: // '
          sb.write('&apos;');
          break;
        default:
          sb.writeCharCode(rune);
      }
    }
  }
  return sb.toString();
}