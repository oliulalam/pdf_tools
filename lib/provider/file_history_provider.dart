import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class FileHistoryProvider extends ChangeNotifier {
  List<String> _filePaths = [];
  static const String _storageKey = 'created_files_history';

  List<String> get filePaths => _filePaths.reversed.toList(); // Newest first

  FileHistoryProvider() {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    _filePaths = prefs.getStringList(_storageKey) ?? [];
    await _cleanNonExistentFiles();
    notifyListeners();
  }

  Future<void> addFile(String path) async {
    if (!_filePaths.contains(path)) {
      _filePaths.add(path);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_storageKey, _filePaths);
      notifyListeners();
    }
  }

  Future<void> removeFile(String path) async {
    _filePaths.remove(path);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_storageKey, _filePaths);
    notifyListeners();
  }

  Future<bool> renameFile(String oldPath, String newPath) async {
    try {
      final file = File(oldPath);
      if (await file.exists()) {
        await file.rename(newPath);
        final index = _filePaths.indexOf(oldPath);
        if (index != -1) {
          _filePaths[index] = newPath;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setStringList(_storageKey, _filePaths);
          notifyListeners();
          return true;
        }
      }
    } catch (e) {
      debugPrint("Error renaming file: $e");
    }
    return false;
  }

  Future<void> _cleanNonExistentFiles() async {
    final List<String> existingFiles = [];
    for (final path in _filePaths) {
      if (await File(path).exists()) {
        existingFiles.add(path);
      }
    }

    if (existingFiles.length != _filePaths.length) {
      _filePaths = existingFiles;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_storageKey, _filePaths);
    }
  }

  Future<void> clearHistory() async {
    _filePaths.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    notifyListeners();
  }
}
