import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'; // For compute
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf_toolkit/provider/file_history_provider.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:open_filex/open_filex.dart';

class PdfPageDeleteProvider extends ChangeNotifier {
  File? _selectedFile;
  int _totalPages = 0;
  bool _isLoading = false;
  String? _statusMessage;

  File? get selectedFile => _selectedFile;
  int get totalPages => _totalPages;
  bool get isLoading => _isLoading;
  String? get statusMessage => _statusMessage;

  Future<void> pickFile() async {
    final FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    final PlatformFile? pickedFile = result?.files.single;

    if (pickedFile != null && pickedFile.path != null) {
      _selectedFile = File(pickedFile.path!);
      final bytes = await _selectedFile!.readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      _totalPages = document.pages.count;
      document.dispose();
      _statusMessage = null;
      notifyListeners();
    }
  }

  Future<bool> deletePagesAndSave(
    BuildContext context,
    List<int> pagesToDelete,
  ) async {
    if (_selectedFile == null) return false;

    _isLoading = true;
    _statusMessage = "Removing pages... (RAM Safe)";
    notifyListeners();

    try {
      final String inputPath = _selectedFile!.path;

      // Use compute with a top-level function to avoid isolate capturing issues
      final Uint8List outputBytes = await compute(
        performPageDeletionFromPathTask,
        DeletePathParams(inputPath: inputPath, pagesToDelete: pagesToDelete),
      );

      final String? path = await FilePicker.saveFile(
        dialogTitle: 'Select where you want to save',
        fileName:
            'Edited_Document_${DateTime.now().millisecondsSinceEpoch}.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: outputBytes,
      );

      if (path == null) {
        _isLoading = false;
        _statusMessage = "Saving process has been canceled";
        notifyListeners();
        return false;
      }

      _isLoading = false;
      _statusMessage = null;
      notifyListeners();

      if (context.mounted) {
        context.read<FileHistoryProvider>().addFile(path);
        await OpenFilex.open(path);
      }
      return true;
    } catch (e) {
      debugPrint("Delete Pages Error: $e");
      _isLoading = false;
      _statusMessage = null;
      notifyListeners();
      return false;
    }
  }

  void reset() {
    _selectedFile = null;
    _totalPages = 0;
    _isLoading = false;
    _statusMessage = null;
    notifyListeners();
  }
}

/// Params class for deletion task
class DeletePathParams {
  final String inputPath;
  final List<int> pagesToDelete;
  const DeletePathParams({
    required this.inputPath,
    required this.pagesToDelete,
  });
}

/// Top-level function for page deletion
Future<Uint8List> performPageDeletionFromPathTask(
  DeletePathParams params,
) async {
  final file = File(params.inputPath);
  final bytes = file.readAsBytesSync();
  final PdfDocument document = PdfDocument(inputBytes: bytes);

  final List<int> sortedPages = List.from(params.pagesToDelete)
    ..sort((a, b) => b.compareTo(a));

  for (int pageNum in sortedPages) {
    if (pageNum >= 1 && pageNum <= document.pages.count) {
      document.pages.removeAt(pageNum - 1);
    }
  }

  final List<int> savedBytes = await document.save();
  document.dispose();
  return Uint8List.fromList(savedBytes);
}
