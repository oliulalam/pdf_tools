import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:open_filex/open_filex.dart';
import 'package:pdf_toolkit/screen/pdf_viewer_screen/pdf_viewer_screen.dart';

String getTrueFileExtension(String path) {
  final ext = p.extension(path).toLowerCase();
  
  // If extension is already specific like .xlsx, .docx, .zip, .csv, .png, .jpg, return it directly
  if (ext == '.xlsx' ||
      ext == '.docx' ||
      ext == '.zip' ||
      ext == '.csv' ||
      ext == '.png' ||
      ext == '.jpg') {
    return ext;
  }

  // If file exists on disk, inspect its magic header bytes
  try {
    final file = File(path);
    if (file.existsSync()) {
      final length = file.lengthSync();
      if (length > 4) {
        final bytes = file.openSync().readSync(math.min(1024, length));
        if (bytes.length >= 4) {
          // Check for PDF signature (%PDF-)
          if (bytes[0] == 0x25 &&
              bytes[1] == 0x50 &&
              bytes[2] == 0x44 &&
              bytes[3] == 0x46) {
            return '.pdf';
          }
          // Check for ZIP magic header (PK\x03\x04)
          if (bytes[0] == 0x50 &&
              bytes[1] == 0x4B &&
              bytes[2] == 0x03 &&
              bytes[3] == 0x04) {
            final str = String.fromCharCodes(bytes);
            if (str.contains('xl/') || str.contains('spreadsheet')) {
              return '.xlsx';
            } else if (str.contains('word/')) {
              return '.docx';
            } else {
              return '.zip';
            }
          }
          // Check for UTF-8 BOM CSV (0xEF 0xBB 0xBF)
          if (bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
            return '.csv';
          }
        }
      }
    }
  } catch (_) {}

  return ext.isNotEmpty ? ext : '.pdf';
}

String displayFileName(String path) {
  var name = p.basename(path);
  final trueExt = getTrueFileExtension(path);

  // 1. Remove 13-digit timestamp prefix if present (e.g. 1793819512345_)
  name = name.replaceFirst(RegExp(r'^\d{13}_'), '');

  // 2. Format technical prefixes into human-readable text
  if (name.startsWith('OCR_Converted_')) {
    name = name.replaceFirst('OCR_Converted_', 'Converted ');
  } else if (name.startsWith('Watermarked_')) {
    name = name.replaceFirst('Watermarked_', 'Watermarked ');
  } else if (name.startsWith('Compressed_')) {
    name = name.replaceFirst('Compressed_', 'Compressed ');
  } else if (name.startsWith('Organized_')) {
    name = name.replaceFirst('Organized_', 'Organized ');
  } else if (name.startsWith('Edited_Document_')) {
    name = name.replaceFirst('Edited_Document_', 'Edited Document ');
  } else if (name.startsWith('Document_')) {
    name = name.replaceFirst('Document_', 'Document ');
  } else if (name.startsWith('split_part_')) {
    final match = RegExp(r'^split_part_(\d+)_').firstMatch(name);
    if (match != null) {
      final partNum = match.group(1);
      name = 'Split Part $partNum$trueExt';
    }
  }

  var baseWithoutExt = p.basenameWithoutExtension(name);

  // If baseWithoutExt is purely digits (like 3315), format as "Document 3315"
  String cleanBase;
  if (RegExp(r'^\d+$').hasMatch(baseWithoutExt)) {
    cleanBase = 'Document $baseWithoutExt';
  } else {
    cleanBase = baseWithoutExt.replaceAll('_', ' ');
  }

  // If cleanBase ends with .pdf but trueExt is different, strip .pdf
  if (cleanBase.toLowerCase().endsWith('.pdf') && trueExt != '.pdf') {
    cleanBase = cleanBase.substring(0, cleanBase.length - 4);
  }

  if (cleanBase.toLowerCase().endsWith(trueExt.toLowerCase())) {
    return cleanBase;
  }

  return '$cleanBase$trueExt';
}

Future<void> openRecentFile(BuildContext context, String path, String title) async {
  final trueExt = getTrueFileExtension(path);

  if (trueExt == '.pdf') {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfViewerScreen(path: path, title: title),
      ),
    );
  } else {
    String openPath = path;
    try {
      final currentExt = p.extension(path).toLowerCase();
      if (currentExt != trueExt && File(path).existsSync()) {
        final dir = p.dirname(path);
        final baseName = p.basenameWithoutExtension(path);
        final correctPath = p.join(dir, '$baseName$trueExt');
        if (!File(correctPath).existsSync()) {
          await File(path).copy(correctPath);
        }
        openPath = correctPath;
      }
    } catch (_) {}

    await OpenFilex.open(openPath);
  }
}
