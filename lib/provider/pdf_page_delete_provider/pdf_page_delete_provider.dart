import 'dart:io';

import 'package:flutter/foundation.dart'; // For compute
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_toolkit/provider/file_history_provider.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:open_filex/open_filex.dart';

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

class PdfPageDeleteProvider extends ChangeNotifier {
  File? _selectedFile;
  int _totalPages = 0;
  bool _isLoading = false;
  String? _statusMessage;

  File? get selectedFile => _selectedFile;
  int get totalPages => _totalPages;
  bool get isLoading => _isLoading;
  String? get statusMessage => _statusMessage;

  Future<bool> pickFile() async {
    try {
      final FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      final PlatformFile? pickedFile = result?.files.single;

      if (pickedFile != null) {
        final File? safeFile = await _getSafeFile(pickedFile);
        if (safeFile != null) {
          _selectedFile = safeFile;
          _totalPages = await compute(_countPagesTask, _selectedFile!.path);
          _statusMessage = null;
          notifyListeners();
          return true;
        }
      }
    } catch (e) {
      debugPrint("Error picking file: $e");
    }
    return false;
  }

  Future<File?> _getSafeFile(PlatformFile pickedFile) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempPath =
          '${tempDir.path}/temp_del_${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}';

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

  Future<bool> deletePagesAndSave(
    BuildContext context,
    List<int> pagesToDelete,
  ) async {
    if (_selectedFile == null) return false;

    // Verify at least one page remains
    if (pagesToDelete.length >= _totalPages) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot remove all pages. At least one page must remain.')),
        );
      }
      return false;
    }

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

      if (path == null || path.isEmpty) {
        _isLoading = false;
        _statusMessage = "Saving process has been canceled";
        notifyListeners();
        return false;
      }

      if (!path.startsWith('/document/')) {
        try {
          final File outFile = File(path);
          if (!await outFile.exists() || (await outFile.length()) == 0) {
            await outFile.writeAsBytes(outputBytes);
          }
        } catch (_) {}
      }

      _isLoading = false;
      _statusMessage = null;
      notifyListeners();

      if (context.mounted) {
        await context.read<FileHistoryProvider>().addFile(path, bytes: outputBytes);
        await OpenFilex.open(path);
      }
      return true;
    } catch (e) {
      debugPrint("Remove Pages Error: $e");
      _isLoading = false;
      _statusMessage = null;
      notifyListeners();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove pages: $e')),
        );
      }
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
