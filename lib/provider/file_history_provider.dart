import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'dart:typed_data';

class FileHistoryProvider extends ChangeNotifier {
  List<String> _filePaths = [];
  static const String _storageKey = 'created_files_history';
  static const int _maxPrivateCopies = 30;
  
  late final Future<void> _ready;

  List<String> get filePaths => _filePaths.reversed.toList(); // Newest first

  FileHistoryProvider() {
    _ready = _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    _filePaths = prefs.getStringList(_storageKey) ?? [];
    await _cleanNonExistentFiles();
    notifyListeners();
  }

  Future<String?> addFile(String path, {Uint8List? bytes, String? preferredFileName}) async {
    await _ready;
    String? finalPath;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final docsDir = Directory('${appDir.path}/PDF_Quant_Documents');
      if (!await docsDir.exists()) {
        await docsDir.create(recursive: true);
      }

      var rawName = (preferredFileName != null && preferredFileName.isNotEmpty)
          ? preferredFileName
          : p.basename(path);

      // If rawName is purely numeric (e.g. 3313 from SAF URI), give it a clean document title
      final baseNoExt = p.basenameWithoutExtension(rawName);
      final rawExt = p.extension(rawName).isNotEmpty
          ? p.extension(rawName)
          : (p.extension(path).isNotEmpty ? p.extension(path) : '.pdf');

      if (RegExp(r'^\d+$').hasMatch(baseNoExt)) {
        rawName = 'Document_$baseNoExt$rawExt';
      } else if (!rawName.contains('.')) {
        rawName = '$rawName$rawExt';
      }

      final originalName = rawName.replaceAll(RegExp(r'[^\w\s.-]'), '');
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$originalName';
      final permanentPath = '${docsDir.path}/$fileName';

      if (bytes != null) {
        final permanentFile = File(permanentPath);
        await permanentFile.writeAsBytes(bytes);
        finalPath = permanentPath;
      } else {
        final file = File(path);
        if (await file.exists()) {
          if (path.startsWith(docsDir.path)) {
            finalPath = path;
          } else {
            await file.copy(permanentPath);
            finalPath = permanentPath;
          }
        } else {
          finalPath = permanentPath;
        }
      }
    } catch (e) {
      debugPrint("Error storing permanent copy: $e");
    }

    if (finalPath == null) return null;

    // Always add finalPath, removing old entry if it existed to bring it to top
    _filePaths.remove(finalPath);
    _filePaths.add(finalPath);
    
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final docsDir = Directory('${appDir.path}/PDF_Quant_Documents');
      while (_filePaths.length > _maxPrivateCopies) {
        final oldestPath = _filePaths.removeAt(0);
        if (oldestPath.startsWith(docsDir.path)) {
          final oldestFile = File(oldestPath);
          if (await oldestFile.exists()) {
            await oldestFile.delete();
          }
        }
      }
    } catch (e) {
      debugPrint("Error removing oldest private copies: $e");
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_storageKey, _filePaths);
    notifyListeners();
    return finalPath;
  }

  Future<void> removeFile(String path) async {
    await _ready;
    _filePaths.remove(path);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_storageKey, _filePaths);
    
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final docsDir = Directory('${appDir.path}/PDF_Quant_Documents');
      if (path.startsWith(docsDir.path)) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      debugPrint("Error deleting private copy: $e");
    }
    
    notifyListeners();
  }

  Future<bool> renameFile(String oldPath, String newPath) async {
    await _ready;
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
    await _ready;
    _filePaths.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final docsDir = Directory('${appDir.path}/PDF_Quant_Documents');
      if (await docsDir.exists()) {
        final entities = docsDir.listSync();
        for (final entity in entities) {
          if (entity is File) {
            try {
              await entity.delete();
            } catch (e) {
              debugPrint("Error deleting file during clearHistory: $e");
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error clearing documents directory: $e");
    }

    notifyListeners();
  }
}
