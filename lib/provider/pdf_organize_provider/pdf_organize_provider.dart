import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf_toolkit/provider/file_history_provider.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class OrganizePageData {
  int originalIndex; // 0-based
  int rotationDegrees; // 0, 90, 180, 270

  OrganizePageData({required this.originalIndex, this.rotationDegrees = 0});
}

class PdfOrganizeProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _statusMessage;
  File? _selectedFile;
  int _totalPages = 0;
  List<OrganizePageData> _pages = [];

  bool get isLoading => _isLoading;
  String? get statusMessage => _statusMessage;
  File? get selectedFile => _selectedFile;
  int get totalPages => _totalPages;
  List<OrganizePageData> get pages => _pages;

  Future<void> pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result != null && result.files.single.path != null) {
        _isLoading = true;
        _statusMessage = "Reading PDF...";
        notifyListeners();

        _selectedFile = File(result.files.single.path!);
        
        final bytes = await _selectedFile!.readAsBytes();
        final doc = PdfDocument(inputBytes: bytes);
        _totalPages = doc.pages.count;
        doc.dispose();

        _pages = List.generate(
          _totalPages,
          (index) => OrganizePageData(originalIndex: index),
        );

        _isLoading = false;
        _statusMessage = null;
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error picking file: $e");
      _isLoading = false;
      _statusMessage = null;
      notifyListeners();
    }
  }

  void reorderPages(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _pages.removeAt(oldIndex);
    _pages.insert(newIndex, item);
    notifyListeners();
  }

  void rotatePage(int index) {
    _pages[index].rotationDegrees = (_pages[index].rotationDegrees + 90) % 360;
    notifyListeners();
  }

  void reset() {
    _selectedFile = null;
    _totalPages = 0;
    _pages.clear();
    _isLoading = false;
    _statusMessage = null;
    notifyListeners();
  }

  Future<bool> saveOrganizedPdf(BuildContext context) async {
    if (_selectedFile == null) return false;

    _isLoading = true;
    _statusMessage = "Organizing PDF...";
    notifyListeners();

    try {
      final bytes = await compute(
        _organizeTask,
        _OrganizeParams(
          inputPath: _selectedFile!.path,
          pages: _pages.map((p) => {'index': p.originalIndex, 'rotation': p.rotationDegrees}).toList(),
        ),
      );

      final String? outputPath = await FilePicker.saveFile(
        dialogTitle: 'Save PDF',
        fileName: 'Organized_${DateTime.now().millisecondsSinceEpoch}.pdf',
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
      debugPrint("Organize Task Error: $e");
      _isLoading = false;
      _statusMessage = "Error occurred during organizing.";
      notifyListeners();
      
      if (context.mounted) {
        String msg = 'Failed to organize PDF.';
        if (e.toString().toLowerCase().contains('password') || e.toString().toLowerCase().contains('encrypt')) {
          msg = 'Failed: Please unlock the PDF before organizing pages.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
      return false;
    }
  }
}

class _OrganizeParams {
  final String inputPath;
  final List<Map<String, int>> pages;
  const _OrganizeParams({required this.inputPath, required this.pages});
}

Future<Uint8List> _organizeTask(_OrganizeParams params) async {
  final bytes = File(params.inputPath).readAsBytesSync();
  final sourceDoc = PdfDocument(inputBytes: bytes);
  final newDoc = PdfDocument();

  PdfSection? currentSection;

  for (var pageData in params.pages) {
    int origIdx = pageData['index']!;
    int rotation = pageData['rotation']!;
    
    final sourcePage = sourceDoc.pages[origIdx];
    final template = sourcePage.createTemplate();
    
    // We apply rotation to the new page by setting the section rotation
    PdfPageOrientation orientation = sourcePage.size.width > sourcePage.size.height
        ? PdfPageOrientation.landscape
        : PdfPageOrientation.portrait;

    if (currentSection == null ||
        currentSection.pageSettings.size != sourcePage.size ||
        currentSection.pageSettings.orientation != orientation) {
      currentSection = newDoc.sections!.add();
      currentSection.pageSettings.size = sourcePage.size;
      currentSection.pageSettings.margins.all = 0;
      currentSection.pageSettings.orientation = orientation;
    }

    final newPage = currentSection.pages.add();
    
    // Apply rotation
    if (rotation == 90) {
      newPage.rotation = PdfPageRotateAngle.rotateAngle90;
    } else if (rotation == 180) {
      newPage.rotation = PdfPageRotateAngle.rotateAngle180;
    } else if (rotation == 270) {
      newPage.rotation = PdfPageRotateAngle.rotateAngle270;
    }

    newPage.graphics.drawPdfTemplate(template, Offset.zero, sourcePage.size);
  }

  final outBytes = await newDoc.save();
  sourceDoc.dispose();
  newDoc.dispose();
  return Uint8List.fromList(outBytes);
}
