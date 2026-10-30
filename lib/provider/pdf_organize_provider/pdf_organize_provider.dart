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
        
        _pages = List.generate(
          _totalPages,
          (index) {
            final page = doc.pages[index];
            int initialRotation = 0;
            if (page.rotation == PdfPageRotateAngle.rotateAngle90) initialRotation = 90;
            if (page.rotation == PdfPageRotateAngle.rotateAngle180) initialRotation = 180;
            if (page.rotation == PdfPageRotateAngle.rotateAngle270) initialRotation = 270;
            
            return OrganizePageData(
              originalIndex: index,
              rotationDegrees: initialRotation,
            );
          },
        );
        doc.dispose();

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

  void removePage(int index) {
    if (_pages.length > 1) {
      _pages.removeAt(index);
      notifyListeners();
    }
  }

  void rotatePage(int index, {bool counterClockwise = false}) {
    if (counterClockwise) {
      _pages[index].rotationDegrees = (_pages[index].rotationDegrees - 90) % 360;
      if (_pages[index].rotationDegrees < 0) _pages[index].rotationDegrees += 360;
    } else {
      _pages[index].rotationDegrees = (_pages[index].rotationDegrees + 90) % 360;
    }
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

    // Verify if there are actual changes
    bool hasChanges = _pages.length != _totalPages;
    for (int i = 0; i < _pages.length; i++) {
      if (_pages[i].originalIndex != i || _pages[i].rotationDegrees != 0) {
        hasChanges = true;
        break;
      }
    }

    if (!hasChanges) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No changes detected to save.')),
      );
      return false;
    }

    _isLoading = true;
    _statusMessage = "Organizing PDF...\n(Note: Forms or links may be lost)";
    notifyListeners();

    try {
      final bytes = await compute(
        _organizeTask,
        _OrganizeParams(
          inputPath: _selectedFile!.path,
          pages: _pages.map((p) => {'index': p.originalIndex, 'rotation': p.rotationDegrees}).toList(),
          hasChanges: hasChanges,
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
  final bool hasChanges;
  const _OrganizeParams({
    required this.inputPath,
    required this.pages,
    required this.hasChanges,
  });
}

Future<Uint8List> _organizeTask(_OrganizeParams params) async {
  final bytes = File(params.inputPath).readAsBytesSync();
  final sourceDoc = PdfDocument(inputBytes: bytes);
  final newDoc = PdfDocument();

  // Try to use templates but warn that forms/links might be lost.
  // Syncfusion free doesn't easily support full importPage with form fields intact in an isolate.
  PdfSection? currentSection;

  for (var pageData in params.pages) {
    int origIdx = pageData['index']!;
    int rotation = pageData['rotation']!;
    
    final sourcePage = sourceDoc.pages[origIdx];
    final template = sourcePage.createTemplate();
    
    // Determine target size based on rotation
    // If rotated by 90 or 270, width and height are swapped
    bool isRotatedSideways = (rotation == 90 || rotation == 270);
    Size targetSize = isRotatedSideways 
        ? Size(sourcePage.size.height, sourcePage.size.width)
        : sourcePage.size;

    PdfPageOrientation targetOrientation = targetSize.width > targetSize.height
        ? PdfPageOrientation.landscape
        : PdfPageOrientation.portrait;

    if (currentSection == null ||
        currentSection.pageSettings.size != targetSize ||
        currentSection.pageSettings.orientation != targetOrientation) {
      currentSection = newDoc.sections!.add();
      currentSection.pageSettings.size = targetSize;
      currentSection.pageSettings.margins.all = 0;
      currentSection.pageSettings.orientation = targetOrientation;
    }

    final newPage = currentSection.pages.add();
    
    // To rotate visually, we translate the graphics context and rotate it
    newPage.graphics.save();
    
    if (rotation == 90) {
      newPage.graphics.translateTransform(targetSize.width, 0);
      newPage.graphics.rotateTransform(90);
    } else if (rotation == 180) {
      newPage.graphics.translateTransform(targetSize.width, targetSize.height);
      newPage.graphics.rotateTransform(180);
    } else if (rotation == 270) {
      newPage.graphics.translateTransform(0, targetSize.height);
      newPage.graphics.rotateTransform(270);
    }

    newPage.graphics.drawPdfTemplate(template, Offset.zero, sourcePage.size);
    newPage.graphics.restore();
  }

  final outBytes = await newDoc.save();
  sourceDoc.dispose();
  newDoc.dispose();
  return Uint8List.fromList(outBytes);
}
