import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:open_filex/open_filex.dart';
import 'package:pdf_toolkit/screen/pdf_viewer_screen/pdf_viewer_screen.dart';

String displayFileName(String path) {
  final baseName = p.basename(path);
  return baseName.replaceFirst(RegExp(r'^\d{13}_'), '');
}

Future<void> openRecentFile(BuildContext context, String path, String title) async {
  if (p.extension(path).toLowerCase() == '.pdf') {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfViewerScreen(path: path, title: title),
      ),
    );
  } else {
    await OpenFilex.open(path);
  }
}
