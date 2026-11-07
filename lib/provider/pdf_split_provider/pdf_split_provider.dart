import 'dart:io';

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

int _countPagesTask(String path) {
  try {
    final File file = File(path);
    final Uint8List bytes = file.readAsBytesSync();
    final PdfDocument document = PdfDocument(inputBytes: bytes);
    final int count = document.pages.count;
    document.dispose();
    return count;
  } catch (_) {
    return 0;
  }
}

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

  void clearGeneratedFiles() {
    if (_generatedFiles.isNotEmpty) {
      _generatedFiles = [];
      _safeNotify();
    }
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

      if (pickedFile != null) {
        final File? safeFile = await _getSafeFile(pickedFile);
        if (safeFile != null) {
          _pdfPath = safeFile.path;
          _pdfName = pickedFile.name;
          _totalPages = await _getPageCountFromPath(_pdfPath!);
          _generatedFiles = [];
          rangeController.clear();
          _safeNotify();
        }
      }
    } catch (e) {
      debugPrint("PDF selection error: $e");
    }
  }

  Future<File?> _getSafeFile(PlatformFile pickedFile) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempPath =
          '${tempDir.path}/temp_split_${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}';

      if (pickedFile.path != null &&
          pickedFile.path!.isNotEmpty &&
          !pickedFile.path!.startsWith('/document/')) {
        final f = File(pickedFile.path!);
        if (await f.exists()) {
          try {
            final bytes = await f.readAsBytes();
            if (bytes.isNotEmpty) {
              final tempFile = File(tempPath);
              await tempFile.writeAsBytes(bytes);
              return tempFile;
            }
          } catch (_) {}
        }
      }

      try {
        final Uint8List bytes = await pickedFile.xFile.readAsBytes();
        if (bytes.isNotEmpty) {
          final tempFile = File(tempPath);
          await tempFile.writeAsBytes(bytes);
          return tempFile;
        }
      } catch (_) {}
    } catch (e) {
      debugPrint("Error preparing safe file: $e");
    }
    return null;
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
    return compute(_countPagesTask, path);
  }

  Future<bool> saveFilesSmart(BuildContext context, {bool showToast = false}) async {
    if (_generatedFiles.isEmpty) return false;

    // If only one file, use direct save picker
    if (_generatedFiles.length == 1) {
      try {
        final String sourcePath = _generatedFiles.first;
        final Uint8List bytes = await File(sourcePath).readAsBytes();

        String? outputPath;
        try {
          outputPath = await FilePicker.saveFile(
            dialogTitle: 'Select Save Location',
            fileName: 'Split_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
            type: FileType.custom,
            allowedExtensions: ['pdf'],
            bytes: bytes,
          );
        } catch (e) {
          debugPrint("FilePicker.saveFile warning: $e");
        }

        // If user cancelled save dialog or backed out
        if (outputPath == null || outputPath.isEmpty) {
          _setStatus('Save cancelled');
          return false;
        }

        if (!outputPath.startsWith('/document/')) {
          try {
            final File outFile = File(outputPath);
            if (!await outFile.exists() || (await outFile.length()) == 0) {
              await outFile.writeAsBytes(bytes);
            }
          } catch (e) {
            debugPrint("Writing to physical outputPath warning: $e");
          }
        }

        if (context.mounted) {
          await context
              .read<FileHistoryProvider>()
              .addFile(outputPath, bytes: bytes);
          _setStatus('Saved successfully!');
          if (showToast) {
            _showToast("PDF saved successfully", Colors.green);
          }
          return true;
        }
        return false;
      } catch (e) {
        debugPrint("Single file save error: $e");
        if (context.mounted) {
          _setStatus('');
        }
        return false;
      }
    } else {
      // If multiple files (Split into parts), create ZIP cleanly in memory with top-level basenames
      try {
        _setStatus('Creating ZIP with ${_generatedFiles.length} PDF files...');

        final archive = Archive();
        for (int i = 0; i < _generatedFiles.length; i++) {
          final sourcePath = _generatedFiles[i];
          final file = File(sourcePath);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            final filename = p.basename(sourcePath);
            archive.addFile(ArchiveFile(filename, bytes.length, bytes));
          }
        }

        final zipData = ZipEncoder().encode(archive);
        final Uint8List zipBytes = Uint8List.fromList(zipData);

        String? outputPath;
        try {
          outputPath = await FilePicker.saveFile(
            dialogTitle: 'Select where you want to save',
            fileName:
                'split_pdf_parts_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.zip',
            type: FileType.custom,
            allowedExtensions: ['zip'],
            bytes: zipBytes,
          );
        } catch (e) {
          debugPrint("FilePicker.saveFile warning: $e");
        }

        // If user cancelled save dialog or backed out
        if (outputPath == null || outputPath.isEmpty) {
          _setStatus('Save cancelled');
          return false;
        }

        if (!outputPath.startsWith('/document/')) {
          try {
            final File outFile = File(outputPath);
            if (!await outFile.exists() || (await outFile.length()) == 0) {
              await outFile.writeAsBytes(zipBytes);
            }
          } catch (e) {
            debugPrint("Writing to physical outputPath warning: $e");
          }
        }

        if (context.mounted) {
          await context
              .read<FileHistoryProvider>()
              .addFile(outputPath, bytes: zipBytes);
          if (showToast) {
            _showToast(
                "${_generatedFiles.length} PDF files saved successfully in ZIP",
                Colors.green);
          }
        }
        _setStatus('Saved successfully!');
        return true;
      } catch (e) {
        debugPrint("Multi-save error: $e");
        if (context.mounted) {
          _showToast("Failed to save ZIP file: $e", Colors.red);
        }
        _setStatus('');
        return false;
      }
    }
  }

  void showSuccessToast() {
    if (_generatedFiles.isEmpty) return;
    if (_generatedFiles.length == 1) {
      _showToast("PDF saved successfully", Colors.green);
    } else {
      _showToast(
          "${_generatedFiles.length} PDF files saved successfully in ZIP",
          Colors.green);
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
    // Cleanup temp generated files to prevent storage leak
    for (final path in _generatedFiles) {
      final file = File(path);
      file.exists().then((exists) {
        if (exists) file.delete().catchError((_) => file);
      });
    }
    _generatedFiles = [];
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
