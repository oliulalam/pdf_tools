import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
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
    String finalPath = path;
    try {
      final file = File(path);
      if (await file.exists()) {
        // Only save to documents dir if it's currently in cache
        if (path.contains('cache') || path.contains('file_picker')) {
          final appDir = await getApplicationDocumentsDirectory();
          final docsDir = Directory('${appDir.path}/PDF_Quant_Documents');
          if (!await docsDir.exists()) {
            await docsDir.create(recursive: true);
          }
          final fileName = path.split(Platform.pathSeparator).last;
          final permanentPath = '${docsDir.path}/$fileName';
          
          // Copy only if destination doesn't already exist to prevent overwrites
          final permanentFile = File(permanentPath);
          if (!await permanentFile.exists()) {
            await file.copy(permanentPath);
          }
          finalPath = permanentPath;
        }
      }
    } catch (e) {
      debugPrint("Error making permanent copy: $e");
    }

    // Always add finalPath, removing old entry if it existed to bring it to top
    _filePaths.remove(finalPath);
    _filePaths.add(finalPath);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_storageKey, _filePaths);
    notifyListeners();
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
