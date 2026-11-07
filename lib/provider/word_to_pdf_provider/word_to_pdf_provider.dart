import 'dart:io';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_toolkit/provider/file_history_provider.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml.dart' as xml;

class WordToPdfProvider extends ChangeNotifier {
  File? _selectedFile;
  String? _selectedFileName;
  bool _isLoading = false;
  String? _statusMessage;

  bool _isA4 = true;
  bool _isLandscape = false;
  double _margin = 36.0; // 36pt standard margin

  File? get selectedFile => _selectedFile;
  String? get selectedFileName => _selectedFileName;
  bool get isLoading => _isLoading;
  String? get statusMessage => _statusMessage;
  bool get isA4 => _isA4;
  bool get isLandscape => _isLandscape;
  double get margin => _margin;

  void setPageSize(bool isA4) {
    _isA4 = isA4;
    notifyListeners();
  }

  void setOrientation(bool isLandscape) {
    _isLandscape = isLandscape;
    notifyListeners();
  }

  void setMargin(double margin) {
    _margin = margin;
    notifyListeners();
  }

  Future<void> pickFile() async {
    try {
      final FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['docx', 'doc'],
      );

      final PlatformFile? pickedFile = result?.files.single;
      if (pickedFile != null) {
        _selectedFileName = pickedFile.name;
        final File? safeFile = await _getSafeFile(pickedFile);
        if (safeFile != null) {
          _selectedFile = safeFile;
          _statusMessage = "Selected: ${pickedFile.name}";
          notifyListeners();
        } else {
          _selectedFile = null;
          _selectedFileName = null;
          _statusMessage = "Could not open selected file.";
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("Error picking Word file: $e");
      _statusMessage = "Error selecting file: $e";
      notifyListeners();
    }
  }

  Future<File?> _getSafeFile(PlatformFile pickedFile) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final safeName = pickedFile.name.replaceAll(RegExp(r'[^\w.-]'), '_');
      final tempPath = '${tempDir.path}/temp_word_${DateTime.now().millisecondsSinceEpoch}_$safeName';

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
      debugPrint("Error preparing safe Word file: $e");
    }
    return null;
  }

  void reset() {
    _selectedFile = null;
    _selectedFileName = null;
    _isLoading = false;
    _statusMessage = null;
    _isA4 = true;
    _isLandscape = false;
    _margin = 36.0;
    notifyListeners();
  }

  Future<bool> convertAndSave(BuildContext context) async {
    if (_selectedFile == null || !await _selectedFile!.exists()) {
      _selectedFile = null;
      _isLoading = false;
      _statusMessage = "Please select a valid Word file first.";
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _statusMessage = "Reading Word document...";
    notifyListeners();

    try {
      final Uint8List docxBytes = await _selectedFile!.readAsBytes();

      _statusMessage = "Generating PDF pages...";
      notifyListeners();

      final Uint8List pdfBytes = await compute(
        _convertDocxToPdfTask,
        _WordToPdfParams(
          inputBytes: docxBytes,
          isA4: _isA4,
          isLandscape: _isLandscape,
          margin: _margin,
        ),
      );

      _statusMessage = "Saving PDF...";
      notifyListeners();

      final String pdfName = (_selectedFileName != null && _selectedFileName!.isNotEmpty)
          ? '${_selectedFileName!.replaceAll(RegExp(r'\.(docx|doc)$', caseSensitive: false), '')}.pdf'
          : 'Converted_${DateTime.now().millisecondsSinceEpoch}.pdf';

      final appDir = await getApplicationDocumentsDirectory();
      final String localPdfPath = '${appDir.path}/$pdfName';
      final File localPdfFile = File(localPdfPath);
      await localPdfFile.writeAsBytes(pdfBytes);

      String? outputPath;
      try {
        outputPath = await FilePicker.saveFile(
          dialogTitle: 'Save PDF Document',
          fileName: pdfName,
          type: FileType.custom,
          allowedExtensions: ['pdf'],
          bytes: pdfBytes,
        );
      } catch (e) {
        debugPrint("FilePicker.saveFile warning: $e");
      }

      if (outputPath == null || outputPath.isEmpty) {
        _isLoading = false;
        _statusMessage = "Save cancelled";
        notifyListeners();
        return false;
      }

      if (!outputPath.startsWith('/document/')) {
        try {
          final File outFile = File(outputPath);
          if (!await outFile.exists() || (await outFile.length()) == 0) {
            await outFile.writeAsBytes(pdfBytes);
          }
        } catch (_) {}
      }

      _isLoading = false;
      _statusMessage = "✅ Saved successfully!";
      notifyListeners();

      if (context.mounted) {
        await Provider.of<FileHistoryProvider>(
          context,
          listen: false,
        ).addFile(outputPath, bytes: pdfBytes);

        try {
          final openResult = await OpenFilex.open(localPdfPath);
          if (openResult.type != ResultType.done) {
            debugPrint("OpenFilex message: ${openResult.message}");
          }
        } catch (_) {}
      }
      return true;
    } catch (e) {
      debugPrint("Word to PDF Error: $e");
      _isLoading = false;
      final errStr = e.toString();
      if (errStr.contains("word/document.xml missing") ||
          errStr.contains("Legacy Word format")) {
        _statusMessage =
            "Legacy Word format (.doc). Please save as .docx or use a standard DOCX file.";
      } else {
        _statusMessage = "Error converting file: $e";
      }
      notifyListeners();
      return false;
    }
  }
}

class _WordToPdfParams {
  final Uint8List inputBytes;
  final bool isA4;
  final bool isLandscape;
  final double margin;

  const _WordToPdfParams({
    required this.inputBytes,
    required this.isA4,
    required this.isLandscape,
    required this.margin,
  });
}

Future<Uint8List> _convertDocxToPdfTask(_WordToPdfParams params) async {
  final pdfDoc = PdfDocument();
  pdfDoc.pageSettings.size = params.isA4 ? PdfPageSize.a4 : PdfPageSize.letter;
  pdfDoc.pageSettings.orientation = params.isLandscape
      ? PdfPageOrientation.landscape
      : PdfPageOrientation.portrait;
  pdfDoc.pageSettings.margins.all = params.margin;

  final titleFont =
      PdfStandardFont(PdfFontFamily.helvetica, 18, style: PdfFontStyle.bold);
  final heading1Font =
      PdfStandardFont(PdfFontFamily.helvetica, 15, style: PdfFontStyle.bold);
  final heading2Font =
      PdfStandardFont(PdfFontFamily.helvetica, 13, style: PdfFontStyle.bold);
  final bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 10.5);
  final boldBodyFont =
      PdfStandardFont(PdfFontFamily.helvetica, 10.5, style: PdfFontStyle.bold);

  PdfPage currentPage = pdfDoc.pages.add();
  double y = 0;
  final double pageWidth = currentPage.getClientSize().width;
  final double pageHeight = currentPage.getClientSize().height;

  PdfPage ensureSpace(double neededHeight) {
    if (y + neededHeight > pageHeight) {
      currentPage = pdfDoc.pages.add();
      y = 0;
    }
    return currentPage;
  }

  // Try decoding as OpenXML .docx zip archive
  Archive? archive;
  try {
    archive = ZipDecoder().decodeBytes(params.inputBytes);
  } catch (_) {}

  ArchiveFile? docXmlFile;
  if (archive != null) {
    for (final file in archive) {
      if (file.name == 'word/document.xml') {
        docXmlFile = file;
        break;
      }
    }
  }

  if (docXmlFile != null) {
    // Process .docx OpenXML
    final xmlString = String.fromCharCodes(docXmlFile.content as List<int>);
    final xmlDocument = xml.XmlDocument.parse(xmlString);

    final bodyElement = xmlDocument.rootElement.findElements('w:body').firstOrNull ??
        xmlDocument.rootElement;

    for (final node in bodyElement.children) {
      if (node is xml.XmlElement) {
        if (node.name.local == 'p') {
          final rawText = _extractTextFromParagraph(node);
          final text = _sanitizeTextForPdfFont(rawText);
          if (text.trim().isEmpty) {
            y += 8;
            continue;
          }

          final xmlStr = node.outerXml;
          final isTitle = xmlStr.contains('Title');
          final isHeading1 = xmlStr.contains('Heading1');
          final isHeading2 =
              xmlStr.contains('Heading2') || xmlStr.contains('Heading3');
          final isBold =
              xmlStr.contains('<w:b/>') || xmlStr.contains('<w:b ');

          final PdfFont font = isTitle
              ? titleFont
              : (isHeading1
                  ? heading1Font
                  : (isHeading2
                      ? heading2Font
                      : (isBold ? boldBodyFont : bodyFont)));

          final double spacing = isHeading1 ? 14 : (isHeading2 ? 10 : 6);
          final format = PdfStringFormat(lineSpacing: 1.5);
          final textSize = font.measureString(text, format: format);

          final targetPage = ensureSpace(textSize.height + spacing);
          targetPage.graphics.drawString(
            text,
            font,
            brush:
                isHeading1 || isHeading2 ? PdfBrushes.indigo : PdfBrushes.black,
            bounds: Rect.fromLTWH(0, y, pageWidth, textSize.height),
            format: format,
          );

          y += textSize.height + spacing;
        } else if (node.name.local == 'tbl') {
          final grid = PdfGrid();
          grid.style.cellPadding =
              PdfPaddings(left: 6, top: 4, right: 6, bottom: 4);

          final trElements = node.findElements('w:tr');
          int maxCols = 0;

          for (final tr in trElements) {
            final tcElements = tr.findElements('w:tc').toList();
            if (tcElements.length > maxCols) {
              maxCols = tcElements.length;
              while (grid.columns.count < maxCols) {
                grid.columns.add();
              }
            }

            final row = grid.rows.add();
            for (int c = 0; c < tcElements.length; c++) {
              final cellText = _sanitizeTextForPdfFont(_extractTextFromElement(tcElements[c])).trim();
              row.cells[c].value = cellText;
              row.cells[c].style.font = bodyFont;
            }
          }

          if (grid.rows.count > 0) {
            final layoutFormat = PdfLayoutFormat(
              layoutType: PdfLayoutType.paginate,
            );

            final targetPage = ensureSpace(40);
            final result = grid.draw(
              page: targetPage,
              bounds: Rect.fromLTWH(0, y, pageWidth, 0),
              format: layoutFormat,
            );

            if (result != null) {
              currentPage = result.page;
              y = result.bounds.bottom + 12;
            }
          }
        }
      }
    }
  } else {
    // Process legacy .doc binary files by extracting clean document paragraphs
    final extractedText = _extractTextFromLegacyDoc(params.inputBytes);
    if (extractedText.isEmpty) {
      throw const FormatException(
          'Could not extract text from this .doc file. Please save as .docx and try again.');
    }

    final lines = extractedText.split('\n');
    final format = PdfStringFormat(lineSpacing: 1.5);

    for (final line in lines) {
      final trimmed = _sanitizeTextForPdfFont(line.trim());
      if (trimmed.isEmpty) {
        y += 6;
        continue;
      }

      final textSize = bodyFont.measureString(trimmed, format: format);
      final targetPage = ensureSpace(textSize.height + 6);
      targetPage.graphics.drawString(
        trimmed,
        bodyFont,
        brush: PdfBrushes.black,
        bounds: Rect.fromLTWH(0, y, pageWidth, textSize.height),
        format: format,
      );
      y += textSize.height + 6;
    }
  }

  final List<int> pdfBytes = await pdfDoc.save();
  pdfDoc.dispose();
  return Uint8List.fromList(pdfBytes);
}

String _sanitizeTextForPdfFont(String text) {
  final sb = StringBuffer();
  for (final char in text.runes) {
    if ((char >= 32 && char <= 126) || char == 10 || char == 13 || char == 9) {
      sb.writeCharCode(char);
    } else {
      switch (char) {
        case 8220: // “
        case 8221: // ”
          sb.write('"');
          break;
        case 8216: // ‘
        case 8217: // ’
          sb.write("'");
          break;
        case 8226: // •
        case 9642: // ▪
        case 9658: // ►
          sb.write('* ');
          break;
        case 8211: // –
        case 8212: // —
          sb.write('-');
          break;
        case 8230: // …
          sb.write('...');
          break;
        case 160: // Non-breaking space
          sb.write(' ');
          break;
        default:
          break;
      }
    }
  }
  return sb.toString();
}

String _extractTextFromLegacyDoc(Uint8List bytes) {
  final sb = StringBuffer();
  final Set<String> seenLines = {};

  void addLineIfValid(String rawLine) {
    final line = rawLine.trim();
    if (line.length < 4) return;
    if (seenLines.contains(line)) return;

    int letters = 0;
    int spaces = 0;
    final total = line.length;

    for (final char in line.runes) {
      if ((char >= 65 && char <= 90) || (char >= 97 && char <= 122)) {
        letters++;
      } else if (char == 32) {
        spaces++;
      }
    }

    if (letters < 4) return;
    if ((letters + spaces) / total < 0.70) return;

    if (line.contains('CompObj') ||
        line.contains('WordDocument') ||
        line.contains('Root Entry') ||
        line.contains('ObjectPool') ||
        line.contains('SummaryInformation') ||
        line.contains('DocumentSummary') ||
        line.contains('Table') ||
        line.contains('Microsoft')) {
      return;
    }

    seenLines.add(line);
    sb.writeln(line);
  }

  // 1. Single byte ASCII scanner
  int i = 0;
  final asciiRunes = <int>[];
  while (i < bytes.length) {
    final b = bytes[i];
    if ((b >= 32 && b <= 126) || b == 10 || b == 13 || b == 9) {
      asciiRunes.add(b);
    } else {
      if (asciiRunes.length >= 4) {
        addLineIfValid(String.fromCharCodes(asciiRunes));
      }
      asciiRunes.clear();
    }
    i++;
  }
  if (asciiRunes.length >= 4) {
    addLineIfValid(String.fromCharCodes(asciiRunes));
  }

  // 2. Double-byte UTF-16LE scanner
  i = 0;
  final utf16Runes = <int>[];
  while (i < bytes.length - 1) {
    final charCode = bytes[i] | (bytes[i + 1] << 8);
    if ((charCode >= 32 && charCode <= 126) ||
        charCode == 10 ||
        charCode == 13 ||
        charCode == 9) {
      utf16Runes.add(charCode);
    } else {
      if (utf16Runes.length >= 4) {
        addLineIfValid(String.fromCharCodes(utf16Runes));
      }
      utf16Runes.clear();
    }
    i += 2;
  }
  if (utf16Runes.length >= 4) {
    addLineIfValid(String.fromCharCodes(utf16Runes));
  }

  return sb.toString().trim();
}

String _extractTextFromParagraph(xml.XmlElement pNode) {
  final sb = StringBuffer();
  for (final child in pNode.findAllElements('w:t')) {
    sb.write(child.innerText);
  }
  return sb.toString();
}

String _extractTextFromElement(xml.XmlElement element) {
  final sb = StringBuffer();
  for (final child in element.findAllElements('w:t')) {
    if (sb.isNotEmpty) sb.write(' ');
    sb.write(child.innerText);
  }
  return sb.toString();
}
