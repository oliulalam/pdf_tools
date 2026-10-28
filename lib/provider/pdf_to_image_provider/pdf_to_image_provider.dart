import 'dart:io';
import 'package:flutter/material.dart';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

class PdfToImageProvider extends ChangeNotifier {
  String? _pdfPath;
  String? _pdfName;
  List<String> _imagePaths = [];
  bool _isConverting = false;
  bool _isZipping = false;
  String _statusMessage = '';

  // Progress tracking
  int _currentProgress = 0;
  int _totalPageCount = 0;

  String? get pdfPath => _pdfPath;
  String? get pdfName => _pdfName;
  List<String> get pageImages => _imagePaths;
  bool get isConverting => _isConverting;
  bool get isZipping => _isZipping;
  bool get hasPdf => _pdfPath != null;
  bool get hasImages => _imagePaths.isNotEmpty;
  String get statusMessage => _statusMessage;

  int get currentProgress => _currentProgress;
  int get totalPageCount => _totalPageCount;
  double get progressValue =>
      _totalPageCount > 0 ? _currentProgress / _totalPageCount : 0.0;

  Future<void> setPdf(String? path, String? name) async {
    _pdfPath = path;
    _pdfName = name;
    await _clearSessionImages();
    _statusMessage = '';
    _currentProgress = 0;
    _totalPageCount = 0;
    notifyListeners();
  }

  Future<void> clearAll() async {
    _pdfPath = null;
    _pdfName = null;
    await _clearSessionImages();
    _isConverting = false;
    _isZipping = false;
    _statusMessage = '';
    _currentProgress = 0;
    _totalPageCount = 0;
    notifyListeners();
  }

  Future<void> _clearSessionImages() async {
    for (final path in _imagePaths) {
      final file = File(path);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (e) {
          debugPrint("Error deleting temp image: $e");
        }
      }
    }
    _imagePaths.clear();
  }

  void setStatus(String message) {
    _statusMessage = message;
    notifyListeners();
  }

  void setConverting(bool value) {
    _isConverting = value;
    if (value) {
      _currentProgress = 0;
    }
    notifyListeners();
  }

  void setZipping(bool value) {
    _isZipping = value;
    notifyListeners();
  }

  void updateProgress(int current, int total) {
    _currentProgress = current;
    _totalPageCount = total;
    notifyListeners();
  }

  void addImage(String path) {
    _imagePaths.add(path);
    notifyListeners();
  }
}
