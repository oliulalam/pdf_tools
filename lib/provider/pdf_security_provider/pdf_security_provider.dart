import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_toolkit/provider/file_history_provider.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path/path.dart' as p;

class PdfSecurityProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _statusMessage;
  File? _selectedFile;
  bool _isLocking = true;

  bool get isLoading => _isLoading;
  String? get statusMessage => _statusMessage;
  File? get selectedFile => _selectedFile;
  bool get isLocking => _isLocking;

  void setMode(bool locking) {
    _isLocking = locking;
    notifyListeners();
  }

  Future<void> pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result != null && result.files.single.path != null) {
        _selectedFile = File(result.files.single.path!);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error picking file: $e");
    }
  }

  void reset() {
    _selectedFile = null;
    _isLoading = false;
    _statusMessage = null;
    notifyListeners();
  }

  Future<bool> processAndSave(BuildContext context, String password) async {
    if (_selectedFile == null || password.isEmpty) return false;

    _isLoading = true;
    _statusMessage = _isLocking ? "Locking PDF..." : "Unlocking PDF...";
    notifyListeners();

    try {
      final bytes = await compute(
        _securityTask,
        _SecurityParams(
          inputPath: _selectedFile!.path,
          password: password,
          isLocking: _isLocking,
        ),
      );

      if (bytes == null) {
        _isLoading = false;
        _statusMessage = "Incorrect password or error occurred";
        notifyListeners();
        return false;
      }

      final fileName = _isLocking 
          ? "Locked_${DateTime.now().millisecondsSinceEpoch}.pdf"
          : "Unlocked_${DateTime.now().millisecondsSinceEpoch}.pdf";

      final String? outputPath = await FilePicker.saveFile(
        dialogTitle: 'Save PDF',
        fileName: fileName,
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
      debugPrint("Security Task Error: $e");
      _isLoading = false;
      _statusMessage = "Error: Invalid password or corrupted file.";
      notifyListeners();
      
      if (context.mounted) {
        String msg = 'Failed to process PDF.';
        if (e.toString().toLowerCase().contains('password') || e.toString().toLowerCase().contains('encrypt')) {
          msg = 'Failed: Please make sure the password is correct, or unlock the PDF first.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
      return false;
    }
  }
}

class _SecurityParams {
  final String inputPath;
  final String password;
  final bool isLocking;
  const _SecurityParams({
    required this.inputPath,
    required this.password,
    required this.isLocking,
  });
}

Future<Uint8List?> _securityTask(_SecurityParams params) async {
  try {
    final bytes = File(params.inputPath).readAsBytesSync();
    PdfDocument document;

    if (params.isLocking) {
      document = PdfDocument(inputBytes: bytes);
      document.security.userPassword = params.password;
      document.security.ownerPassword = params.password;
      document.security.algorithm = PdfEncryptionAlgorithm.aesx256Bit;
    } else {
      document = PdfDocument(inputBytes: bytes, password: params.password);
      document.security.userPassword = '';
      document.security.ownerPassword = '';
    }

    final outBytes = await document.save();
    document.dispose();
    return Uint8List.fromList(outBytes);
  } catch (e) {
    debugPrint("Background task exception: $e");
    return null;
  }
}
