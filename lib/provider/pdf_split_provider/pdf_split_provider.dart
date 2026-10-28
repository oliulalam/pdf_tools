import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'; // For compute
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:pdf_toolkit/provider/file_history_provider.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:archive/archive_io.dart';

class PdfSplitProvider extends ChangeNotifier {
  bool _isLoading = false;
  List<String> _generatedFiles = [];
  int? _totalPages;
  String? _pdfPath;
  String? _pdfName;
  bool _isDisposed = false;
  String _statusMessage = '';

  bool get isLoading => _isLoading;
  List<String> get generatedFiles => List.unmodifiable(_generatedFiles);
  int? get totalPages => _totalPages;
  String? get pdfPath => _pdfPath;
  String? get pdfName => _pdfName;
  String get statusMessage => _statusMessage;

  final TextEditingController rangeController = TextEditingController();

  bool get isInputValid => rangeController.text.trim().isNotEmpty;
  String get missingInputMessage => 'Enter page range (e.g., 1-5, 8, 10-12)';

  void _safeNotify() {
    if (!_isDisposed) notifyListeners();
  }

  void _setStatus(String msg) {
    _statusMessage = msg;
    _safeNotify();
  }

  void reset() {
    _generatedFiles = [];
    _totalPages = null;
    _pdfPath = null;
    _pdfName = null;
    _statusMessage = '';
    rangeController.clear();
    _isLoading = false;
    _safeNotify();
  }

  List<List<int>>? _parseRangeGroups(String input, int total) {
    final List<List<int>> groups = [];
    if (input.trim().isEmpty) return groups;

    for (final part in input.split(',')) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;

      final List<int> currentGroup = [];
      if (trimmed.contains('-')) {
        final parts = trimmed.split('-');
        if (parts.length != 2) continue;

        final start = int.tryParse(parts[0].trim());
        final end = int.tryParse(parts[1].trim());

        if (start == null || end == null || start < 1 || end < start) {
          continue;
        }
        if (start > total || end > total) return null;

        for (int i = start; i <= end; i++) {
          currentGroup.add(i);
        }
      } else {
        final page = int.tryParse(trimmed);
        if (page != null) {
          if (page < 1 || page > total) return null;
          currentGroup.add(page);
        }
      }
      
      if (currentGroup.isNotEmpty) {
        groups.add(currentGroup.toSet().toList()..sort());
      }
    }
    return groups;
  }

  Future<void> pickPdf(BuildContext context) async {
    try {
      final FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      final PlatformFile? pickedFile = result?.files.single;

      if (pickedFile != null && pickedFile.path != null) {
        _pdfPath = pickedFile.path;
        _pdfName = pickedFile.name;
        _totalPages = await _getPageCountFromPath(_pdfPath!);
        _generatedFiles = [];
        rangeController.clear();
        _safeNotify();
      }
    } catch (e) {
      debugPrint("PDF selection error: $e");
    }
  }

  Future<bool> splitSelectedPdf(BuildContext context, {bool splitIntoParts = false}) async {
    if (_pdfPath == null) return false;

    if (!isInputValid) {
      if (context.mounted) {
        _showToast(missingInputMessage, Colors.orange[800]!);
      }
      return false;
    }

    _isLoading = true;
    _generatedFiles = [];
    _setStatus('Splitting document...');
    _safeNotify();

    try {
      final sourcePath = _pdfPath!;
      final total = _totalPages ?? await _getPageCountFromPath(sourcePath);

      final groupedIndices = _parseRangeGroups(rangeController.text, total);
      if (groupedIndices == null) {
        _isLoading = false;
        _setStatus('');
        if (context.mounted) {
          _showToast(
            'Invalid range: This PDF only has $total pages.',
            Colors.red[800]!,
          );
        }
        return false;
      }
      if (groupedIndices.isEmpty) throw Exception('Please enter a valid page range.');

      // Flatten for Extract mode
      final Set<int> allPagesSet = {};
      for (var group in groupedIndices) {
        allPagesSet.addAll(group);
      }
      final List<int> flatIndices = allPagesSet.toList()..sort();

      _setStatus('Splitting document...');

      if (!splitIntoParts) {
        // Mode 1: Extract pages (Single PDF output)
        final Uint8List outputBytes = await compute(
          splitPdfFromPathTask,
          SplitPathParams(sourcePath: sourcePath, pageIndices: flatIndices),
        );

        final dir = await getTemporaryDirectory();
        final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        final outputFilePath = p.join(dir.path, 'split_$timestamp.pdf');

        await File(outputFilePath).writeAsBytes(outputBytes, flush: true);
        _generatedFiles = [outputFilePath];
      } else {
        // Mode 2: Split into parts (Multiple PDF outputs, 1 for each range group)
        final List<String> parts = [];
        final dir = await getTemporaryDirectory();
        final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

        for (int i = 0; i < groupedIndices.length; i++) {
          final group = groupedIndices[i];
          final Uint8List groupBytes = await compute(
            splitPdfFromPathTask,
            SplitPathParams(sourcePath: sourcePath, pageIndices: group),
          );
          final outputFilePath = p.join(dir.path, 'split_part_${i + 1}_$timestamp.pdf');
          await File(outputFilePath).writeAsBytes(groupBytes, flush: true);
          parts.add(outputFilePath);
        }
        _generatedFiles = parts;
      }

      _isLoading = false;
      _setStatus('');

      return true;
    } catch (e) {
      debugPrint("Split Error: $e");
      _isLoading = false;
      _setStatus('');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to split PDF: $e')),
        );
      }
      return false;
    }
  }

  Future<int> _getPageCountFromPath(String path) async {
    PdfDocument? doc;
    try {
      final bytes = await File(path).readAsBytes();
      doc = PdfDocument(inputBytes: bytes);
      return doc.pages.count;
    } catch (_) {
      return 0;
    } finally {
      doc?.dispose();
    }
  }

  Future<bool> saveFilesSmart(BuildContext context) async {
    if (_generatedFiles.isEmpty) return false;
    
    // If only one file, use direct save picker
    if (_generatedFiles.length == 1) {
      try {
        final String sourcePath = _generatedFiles.first;
        final Uint8List bytes = await File(sourcePath).readAsBytes();

        final String? outputPath = await FilePicker.saveFile(
          dialogTitle: 'Select Save Location',
          fileName: 'Split_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
          type: FileType.custom,
          allowedExtensions: ['pdf'],
          bytes: bytes,
        );

        if (outputPath != null && context.mounted) {
          context.read<FileHistoryProvider>().addFile(outputPath);
          _setStatus('');
          return true;
        }
        return false;
      } catch (e) {
        if (context.mounted) {
          _setStatus('');
        }
        return false;
      }
    } else {
      // If multiple files (Split into parts), save as a ZIP file like pdf to image
      try {
        _setStatus('Zipping files...');
        final tempDir = await getTemporaryDirectory();
        final workingDir = Directory(
          '${tempDir.path}/zip_out_${DateTime.now().millisecondsSinceEpoch}',
        );
        await workingDir.create(recursive: true);

        final tempZipPath = '${workingDir.path}/split_parts.zip';

        final encoder = ZipFileEncoder();
        encoder.create(tempZipPath);

        for (var sourcePath in _generatedFiles) {
          final file = File(sourcePath);
          if (await file.exists()) {
            encoder.addFile(file);
          }
        }
        encoder.close();

        final sourceZip = File(tempZipPath);
        final zipBytes = await sourceZip.readAsBytes();

        final String? outputPath = await FilePicker.saveFile(
          dialogTitle: 'Select where you want to save',
          fileName: 'split_pdf_parts_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.zip',
          type: FileType.custom,
          allowedExtensions: ['zip'],
          bytes: zipBytes,
        );

        if (outputPath != null) {
          if (context.mounted) {
            context.read<FileHistoryProvider>().addFile(outputPath);
            _showToast("Files saved successfully as ZIP", Colors.green);
          }
          _setStatus('');
          if (await workingDir.exists()) await workingDir.delete(recursive: true);
          return true;
        } else {
          if (await workingDir.exists()) await workingDir.delete(recursive: true);
          _setStatus('');
          return false;
        }
      } catch (e) {
        debugPrint("Multi-save error: $e");
        if (context.mounted) {
          _showToast("Failed to save ZIP file", Colors.red);
        }
        _setStatus('');
        return false;
      }
    }
  }

  void _showToast(String message, Color color) {
    Fluttertoast.showToast(
      msg: message,
      backgroundColor: color,
      gravity: ToastGravity.CENTER,
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    rangeController.dispose();
    super.dispose();
  }
}

/// Params class for splitting task
class SplitPathParams {
  final String sourcePath;
  final List<int> pageIndices;
  const SplitPathParams({required this.sourcePath, required this.pageIndices});
}

/// Top-level function for splitting PDF with exact page size matching
Future<Uint8List> splitPdfFromPathTask(SplitPathParams params) async {
  PdfDocument? sourceDoc;
  PdfDocument? outputDoc;

  try {
    final file = File(params.sourcePath);
    final bytes = file.readAsBytesSync();

    sourceDoc = PdfDocument(inputBytes: bytes);
    outputDoc = PdfDocument();
    PdfSection? currentSection;

    for (final pageNumber in params.pageIndices) {
      if (pageNumber >= 1 && pageNumber <= sourceDoc.pages.count) {
        final sourcePage = sourceDoc.pages[pageNumber - 1];
        final orientation = sourcePage.size.width > sourcePage.size.height
            ? PdfPageOrientation.landscape
            : PdfPageOrientation.portrait;

        // Create a new section if size or orientation changes to maintain exact dimensions
        if (currentSection == null ||
            currentSection.pageSettings.size != sourcePage.size ||
            currentSection.pageSettings.orientation != orientation) {
          currentSection = outputDoc.sections!.add();
          currentSection.pageSettings.size = sourcePage.size;
          currentSection.pageSettings.margins.all = 0;
          currentSection.pageSettings.orientation = orientation;
        }

        final PdfPage page = currentSection.pages.add();
        final PdfTemplate template = sourcePage.createTemplate();
        page.graphics.drawPdfTemplate(template, Offset.zero, sourcePage.size);
      }
    }

    final List<int> outputBytes = await outputDoc.save();
    return Uint8List.fromList(outputBytes);
  } catch (e) {
    rethrow;
  } finally {
    sourceDoc?.dispose();
    outputDoc?.dispose();
  }
}
