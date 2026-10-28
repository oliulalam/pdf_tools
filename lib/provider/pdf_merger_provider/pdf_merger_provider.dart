import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'; // For compute
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdf_toolkit/provider/file_history_provider.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:fluttertoast/fluttertoast.dart';

class PdfMergerProvider extends ChangeNotifier {
  final List<File> _selectedFiles = [];
  final Map<String, double> _fileSizes = {}; // Cache file sizes

  bool _isMerging = false;
  String? _statusMessage;

  List<File> get selectedFiles => List.unmodifiable(_selectedFiles);
  int get fileCount => _selectedFiles.length;
  bool get isMerging => _isMerging;
  String? get statusMessage => _statusMessage;
  bool get hasFile => _selectedFiles.isNotEmpty;

  double getFileSize(String path) => _fileSizes[path] ?? 0.0;

  void addFiles(List<File> files) async {
    if (files.isEmpty) return;
    for (var file in files) {
      _selectedFiles.add(file);
      // Fetch size asynchronously
      final size = await file.length();
      _fileSizes[file.path] = size / 1024;
    }
    notifyListeners();
  }

  Future<void> pickFiles() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );

    if (result != null) {
      addFiles(
        result.paths.whereType<String>().map((path) => File(path)).toList(),
      );
    }
  }

  void removeFile(int index) {
    if (index < 0 || index >= _selectedFiles.length) return;
    final file = _selectedFiles.removeAt(index);
    _fileSizes.remove(file.path);
    notifyListeners();
  }

  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < 0 ||
        oldIndex >= _selectedFiles.length ||
        newIndex < 0 ||
        newIndex > _selectedFiles.length) {
      return;
    }
    if (oldIndex == newIndex) return;

    final file = _selectedFiles.removeAt(oldIndex);
    _selectedFiles.insert(newIndex, file);
    notifyListeners();
  }

  void clearAll() {
    _selectedFiles.clear();
    _fileSizes.clear();
    _isMerging = false;
    _statusMessage = null;
    notifyListeners();
  }

  void setMerging(bool value) {
    if (_isMerging == value) return;
    _isMerging = value;
    notifyListeners();
  }

  void setStatusMessage(String? message) {
    if (_statusMessage == message) return;
    _statusMessage = message;
    notifyListeners();
  }

  void showToast(String message, {bool isError = false}) {
    Fluttertoast.showToast(
      msg: message,
      backgroundColor: isError ? Colors.red : Colors.green,
      gravity: ToastGravity.CENTER,
      toastLength: Toast.LENGTH_LONG,
    );
  }

  Future<bool> mergeAndSave(
    BuildContext context, {
    String? customFileName,
  }) async {
    if (_selectedFiles.length < 2) {
      showToast('Please select at least 2 PDF files to merge', isError: true);
      return false;
    }

    setMerging(true);
    setStatusMessage("Merging PDFs... This may take a moment");

    try {
      final List<String> filePaths = _selectedFiles.map((f) => f.path).toList();

      // Use compute to prevent capturing class instances or other unsendable objects
      final Uint8List mergedBytes = await compute(
        performMergeFromPathsTask,
        filePaths,
      );

      final String suggestedName = customFileName?.trim().isNotEmpty == true
          ? '${customFileName!.trim()}.pdf'
          : 'Merged_PDF_${DateTime.now().millisecondsSinceEpoch}.pdf';

      final String? savePath = await FilePicker.saveFile(
        dialogTitle: 'Select where you want to save',
        fileName: suggestedName,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: mergedBytes,
      );

      setMerging(false);

      if (savePath != null) {
        setStatusMessage(null);
        if (context.mounted) {
          context.read<FileHistoryProvider>().addFile(savePath);
          try {
            await OpenFilex.open(savePath);
          } catch (e) {
            debugPrint('Could not open file: $e');
          }
        }
        return true;
      } else {
        setStatusMessage(null);
        return false;
      }
    } catch (e) {
      debugPrint("Merge Error: $e");
      setMerging(false);
      setStatusMessage(null);
      return false;
    }
  }
}

/// Top-level function for PDF merging to be used with compute.
/// Independent of any provider or state instances.
Future<Uint8List> performMergeFromPathsTask(List<String> paths) async {
  final finalDoc = PdfDocument();
  PdfSection? currentSection;

  for (final path in paths) {
    final file = File(path);
    if (!file.existsSync()) continue;

    final bytes = file.readAsBytesSync();
    final sourceDoc = PdfDocument(inputBytes: bytes);

    for (var i = 0; i < sourceDoc.pages.count; i++) {
      final page = sourceDoc.pages[i];
      final template = page.createTemplate();
      final orientation = template.size.width > template.size.height
          ? PdfPageOrientation.landscape
          : PdfPageOrientation.portrait;

      if (currentSection == null ||
          currentSection.pageSettings.size != template.size ||
          currentSection.pageSettings.orientation != orientation) {
        currentSection = finalDoc.sections!.add();
        currentSection.pageSettings
          ..size = template.size
          ..margins.all = 0
          ..orientation = orientation;
      }

      final newPage = currentSection.pages.add();
      newPage.graphics.drawPdfTemplate(template, Offset.zero, template.size);
    }
    sourceDoc.dispose();
  }

  final List<int> mergedBytesList = await finalDoc.save();
  final result = Uint8List.fromList(mergedBytesList);
  finalDoc.dispose();
  return result;
}
