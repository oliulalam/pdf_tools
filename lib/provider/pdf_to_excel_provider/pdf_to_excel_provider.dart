import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf_toolkit/provider/file_history_provider.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:csv/csv.dart';

class PdfToExcelProvider extends ChangeNotifier {
  File? _selectedFile;
  bool _isLoading = false;
  String? _statusMessage;
  double _progress = 0.0;
  bool _isCancelled = false;

  // Review state
  List<List<String>>? _extractedGrid;

  File? get selectedFile => _selectedFile;
  bool get isLoading => _isLoading;
  String? get statusMessage => _statusMessage;
  double get progress => _progress;
  List<List<String>>? get extractedGrid => _extractedGrid;

  Future<void> pickFile() async {
    final FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    final PlatformFile? pickedFile = result?.files.single;

    if (pickedFile != null && pickedFile.path != null) {
      _selectedFile = File(pickedFile.path!);
      _statusMessage = "Selected: ${pickedFile.name}";
      _progress = 0.0;
      _extractedGrid = null;
      notifyListeners();
    }
  }

  void cancel() {
    _isCancelled = true;
    _isLoading = false;
    _statusMessage = "Operation cancelled";
    notifyListeners();
  }

  void updateGridCell(int row, int col, String value) {
    if (_extractedGrid != null &&
        row < _extractedGrid!.length &&
        col < _extractedGrid![row].length) {
      _extractedGrid![row][col] = value;
      notifyListeners();
    }
  }

  Future<bool> extractTableForReview() async {
    if (_selectedFile == null) return false;

    _isLoading = true;
    _progress = 0.0;
    _isCancelled = false;
    _extractedGrid = null;
    _statusMessage = "Analyzing PDF structure...";
    notifyListeners();

    PdfDocument? document;
    List<List<String>> grid = [];

    try {
      final Uint8List bytes = await _selectedFile!.readAsBytes();
      document = PdfDocument(inputBytes: bytes);
      final PdfTextExtractor extractor = PdfTextExtractor(document);

      for (int i = 0; i < document.pages.count; i++) {
        if (_isCancelled) {
          document.dispose();
          return false;
        }

        _statusMessage =
            "Extracting Page ${i + 1} of ${document.pages.count}...";
        _progress = (i + 1) / document.pages.count;
        notifyListeners();

        final String pageText = extractor.extractText(
          startPageIndex: i,
          endPageIndex: i,
        );

        // Heuristic splitting
        final List<String> lines = pageText.split('\n');
        for (var line in lines) {
          if (line.trim().isEmpty) continue;

          // Split by 2 or more spaces to approximate columns
          final List<String> columns = line.trim().split(RegExp(r'\s{2,}'));
          grid.add(columns);
        }
      }

      _extractedGrid = grid;
      _isLoading = false;
      _statusMessage = "Extraction Complete. Review data.";
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("PDF to Excel Extraction Error: $e");
      _isLoading = false;
      _statusMessage = "Error: Extraction failed";
      notifyListeners();
      return false;
    } finally {
      document?.dispose();
    }
  }

  Future<bool> saveAsExcel(BuildContext context) async {
    if (_extractedGrid == null) return false;

    _isLoading = true;
    _statusMessage = "Generating Excel file...";
    notifyListeners();

    final Workbook workbook = Workbook();
    final Worksheet sheet = workbook.worksheets[0];

    try {
      for (int r = 0; r < _extractedGrid!.length; r++) {
        for (int c = 0; c < _extractedGrid![r].length; c++) {
          sheet.getRangeByIndex(r + 1, c + 1).setText(_extractedGrid![r][c]);
        }
      }

      final List<int> excelBytes = workbook.saveAsStream();
      workbook.dispose();

      final String? outputPath = await FilePicker.saveFile(
        dialogTitle: 'Save Excel Document',
        fileName: 'Converted_${DateTime.now().millisecondsSinceEpoch}.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        bytes: Uint8List.fromList(excelBytes),
      );

      return _handleSaveSuccess(context, outputPath);
    } catch (e) {
      debugPrint("Excel Save Error: $e");
      _isLoading = false;
      _statusMessage = "Save failed";
      notifyListeners();
      return false;
    }
  }

  Future<bool> saveAsCsv(BuildContext context) async {
    if (_extractedGrid == null) return false;

    _isLoading = true;
    _statusMessage = "Generating CSV file...";
    notifyListeners();

    try {
      String csvData = Csv().encode(_extractedGrid!);

      // UTF-8 BOM for Excel compatibility
      final List<int> bytes = [0xEF, 0xBB, 0xBF, ...csvData.codeUnits];

      final String? outputPath = await FilePicker.saveFile(
        dialogTitle: 'Save CSV Document',
        fileName: 'Converted_${DateTime.now().millisecondsSinceEpoch}.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: Uint8List.fromList(bytes),
      );

      return _handleSaveSuccess(context, outputPath);
    } catch (e) {
      debugPrint("CSV Save Error: $e");
      _isLoading = false;
      _statusMessage = "Save failed";
      notifyListeners();
      return false;
    }
  }

  bool _handleSaveSuccess(BuildContext context, String? outputPath) {
    if (outputPath == null) {
      _isLoading = false;
      _statusMessage = "Save cancelled";
      notifyListeners();
      return false;
    }

    _isLoading = false;
    _statusMessage = "✅ Successfully saved!";
    notifyListeners();

    if (context.mounted) {
      Provider.of<FileHistoryProvider>(
        context,
        listen: false,
      ).addFile(outputPath);
      OpenFilex.open(outputPath);
    }
    return true;
  }

  void reset() {
    _selectedFile = null;
    _isLoading = false;
    _statusMessage = null;
    _progress = 0.0;
    _isCancelled = false;
    _extractedGrid = null;
    notifyListeners();
  }
}
