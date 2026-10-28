import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class PdfPresenterProvider extends ChangeNotifier {
  File? _selectedFile;
  bool _isLoading = false;
  String? _statusMessage;

  File? get selectedFile => _selectedFile;
  bool get isLoading => _isLoading;
  String? get statusMessage => _statusMessage;

  Future<void> pickFile() async {
    _isLoading = true;
    notifyListeners();

    try {
      final FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      final PlatformFile? pickedFile = result?.files.single;

      if (pickedFile != null && pickedFile.path != null) {
        _selectedFile = File(pickedFile.path!);
        _statusMessage = null;
      } else {
        _statusMessage = "Selection cancelled";
      }
    } catch (e) {
      debugPrint("File picking error: $e");
      _statusMessage = "Error picking file";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void reset() {
    _selectedFile = null;
    _isLoading = false;
    _statusMessage = null;
    notifyListeners();
  }
}
