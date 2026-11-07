import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_toolkit/provider/file_history_provider.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

enum EditTool { pointer, text, image, shape, freehand }
enum ShapeType { rectangle, circle, line }

class PdfTextAnnotation {
  final String id;
  final int pageIndex;
  String text;
  Offset position; // Normalized (0..1)
  double fontSize;
  Color color;
  bool isBold;

  PdfTextAnnotation({
    required this.id,
    required this.pageIndex,
    required this.text,
    required this.position,
    this.fontSize = 18.0,
    this.color = Colors.red,
    this.isBold = false,
  });
}

class PdfImageAnnotation {
  final String id;
  final int pageIndex;
  final Uint8List imageBytes;
  Offset position; // Normalized (0..1)
  Size size; // Normalized (0..1)

  PdfImageAnnotation({
    required this.id,
    required this.pageIndex,
    required this.imageBytes,
    required this.position,
    required this.size,
  });
}

class PdfShapeAnnotation {
  final String id;
  final int pageIndex;
  ShapeType shapeType;
  Offset startPoint; // Normalized
  Offset endPoint; // Normalized
  Color color;
  double strokeWidth;
  bool isFilled;

  PdfShapeAnnotation({
    required this.id,
    required this.pageIndex,
    required this.shapeType,
    required this.startPoint,
    required this.endPoint,
    this.color = Colors.blue,
    this.strokeWidth = 3.0,
    this.isFilled = false,
  });
}

class PdfFreehandPath {
  final String id;
  final int pageIndex;
  List<Offset> points; // Normalized points
  Color color;
  double strokeWidth;

  PdfFreehandPath({
    required this.id,
    required this.pageIndex,
    required this.points,
    this.color = Colors.red,
    this.strokeWidth = 3.0,
  });
}

class PdfEditProvider extends ChangeNotifier {
  File? _selectedFile;
  String? _selectedFileName;
  int _totalPages = 0;
  int _currentPageIndex = 0;
  bool _isLoading = false;
  String? _statusMessage;

  EditTool _activeTool = EditTool.pointer;
  ShapeType _activeShapeType = ShapeType.rectangle;
  Color _activeColor = Colors.red;
  double _activeFontSize = 18.0;
  double _activeStrokeWidth = 3.0;

  final List<PdfTextAnnotation> _texts = [];
  final List<PdfImageAnnotation> _images = [];
  final List<PdfShapeAnnotation> _shapes = [];
  final List<PdfFreehandPath> _freehandPaths = [];

  File? get selectedFile => _selectedFile;
  String? get selectedFileName => _selectedFileName;
  int get totalPages => _totalPages;
  int get currentPageIndex => _currentPageIndex;
  bool get isLoading => _isLoading;
  String? get statusMessage => _statusMessage;

  EditTool get activeTool => _activeTool;
  ShapeType get activeShapeType => _activeShapeType;
  Color get activeColor => _activeColor;
  double get activeFontSize => _activeFontSize;
  double get activeStrokeWidth => _activeStrokeWidth;

  List<PdfTextAnnotation> get texts => List.unmodifiable(_texts);
  List<PdfImageAnnotation> get images => List.unmodifiable(_images);
  List<PdfShapeAnnotation> get shapes => List.unmodifiable(_shapes);
  List<PdfFreehandPath> get freehandPaths => List.unmodifiable(_freehandPaths);

  void setActiveTool(EditTool tool) {
    _activeTool = tool;
    notifyListeners();
  }

  void setActiveShapeType(ShapeType type) {
    _activeShapeType = type;
    notifyListeners();
  }

  void setActiveColor(Color color) {
    _activeColor = color;
    notifyListeners();
  }

  void setActiveFontSize(double size) {
    _activeFontSize = size;
    notifyListeners();
  }

  void setActiveStrokeWidth(double width) {
    _activeStrokeWidth = width;
    notifyListeners();
  }

  void setCurrentPageIndex(int index) {
    if (index >= 0 && index < _totalPages) {
      _currentPageIndex = index;
      notifyListeners();
    }
  }

  Future<bool> pickFile() async {
    try {
      final FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      final PlatformFile? pickedFile = result?.files.single;
      if (pickedFile != null) {
        _selectedFileName = pickedFile.name;
        final File? safeFile = await _getSafeFile(pickedFile);
        if (safeFile != null) {
          _selectedFile = safeFile;
          _totalPages = await compute(_countPagesTask, _selectedFile!.path);
          _currentPageIndex = 0;
          _clearAnnotations();
          _statusMessage = null;
          notifyListeners();
          return true;
        }
      }
    } catch (e) {
      debugPrint("Error picking PDF file: $e");
    }
    return false;
  }

  Future<File?> _getSafeFile(PlatformFile pickedFile) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempPath =
          '${tempDir.path}/temp_edit_${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}';

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
      debugPrint("Error preparing safe PDF file: $e");
    }
    return null;
  }

  void addText(String text, Offset normalizedPos) {
    _texts.add(
      PdfTextAnnotation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        pageIndex: _currentPageIndex,
        text: text,
        position: normalizedPos,
        fontSize: _activeFontSize,
        color: _activeColor,
      ),
    );
    notifyListeners();
  }

  void updateText(String id, {String? text, double? fontSize, Color? color, Offset? position}) {
    final idx = _texts.indexWhere((t) => t.id == id);
    if (idx != -1) {
      if (text != null) _texts[idx].text = text;
      if (fontSize != null) _texts[idx].fontSize = fontSize;
      if (color != null) _texts[idx].color = color;
      if (position != null) _texts[idx].position = position;
      notifyListeners();
    }
  }

  void removeText(String id) {
    _texts.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  void addImage(Uint8List bytes, Offset normalizedPos, Size normalizedSize) {
    _images.add(
      PdfImageAnnotation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        pageIndex: _currentPageIndex,
        imageBytes: bytes,
        position: normalizedPos,
        size: normalizedSize,
      ),
    );
    notifyListeners();
  }

  void removeImage(String id) {
    _images.removeWhere((img) => img.id == id);
    notifyListeners();
  }

  void addShape(ShapeType type, Offset start, Offset end) {
    _shapes.add(
      PdfShapeAnnotation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        pageIndex: _currentPageIndex,
        shapeType: type,
        startPoint: start,
        endPoint: end,
        color: _activeColor,
        strokeWidth: _activeStrokeWidth,
      ),
    );
    notifyListeners();
  }

  void removeShape(String id) {
    _shapes.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  void addFreehandPath(List<Offset> points) {
    if (points.isEmpty) return;
    _freehandPaths.add(
      PdfFreehandPath(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        pageIndex: _currentPageIndex,
        points: List.from(points),
        color: _activeColor,
        strokeWidth: _activeStrokeWidth,
      ),
    );
    notifyListeners();
  }

  void removeFreehandPath(String id) {
    _freehandPaths.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  void undoLastAnnotation() {
    if (_freehandPaths.any((p) => p.pageIndex == _currentPageIndex)) {
      final lastIdx = _freehandPaths.lastIndexWhere((p) => p.pageIndex == _currentPageIndex);
      if (lastIdx != -1) _freehandPaths.removeAt(lastIdx);
    } else if (_shapes.any((s) => s.pageIndex == _currentPageIndex)) {
      final lastIdx = _shapes.lastIndexWhere((s) => s.pageIndex == _currentPageIndex);
      if (lastIdx != -1) _shapes.removeAt(lastIdx);
    } else if (_texts.any((t) => t.pageIndex == _currentPageIndex)) {
      final lastIdx = _texts.lastIndexWhere((t) => t.pageIndex == _currentPageIndex);
      if (lastIdx != -1) _texts.removeAt(lastIdx);
    } else if (_images.any((img) => img.pageIndex == _currentPageIndex)) {
      final lastIdx = _images.lastIndexWhere((img) => img.pageIndex == _currentPageIndex);
      if (lastIdx != -1) _images.removeAt(lastIdx);
    }
    notifyListeners();
  }

  void clearPageAnnotations() {
    _texts.removeWhere((t) => t.pageIndex == _currentPageIndex);
    _images.removeWhere((img) => img.pageIndex == _currentPageIndex);
    _shapes.removeWhere((s) => s.pageIndex == _currentPageIndex);
    _freehandPaths.removeWhere((p) => p.pageIndex == _currentPageIndex);
    notifyListeners();
  }

  void _clearAnnotations() {
    _texts.clear();
    _images.clear();
    _shapes.clear();
    _freehandPaths.clear();
  }

  void reset() {
    _selectedFile = null;
    _selectedFileName = null;
    _totalPages = 0;
    _currentPageIndex = 0;
    _isLoading = false;
    _statusMessage = null;
    _activeTool = EditTool.pointer;
    _activeShapeType = ShapeType.rectangle;
    _activeColor = Colors.red;
    _activeFontSize = 18.0;
    _activeStrokeWidth = 3.0;
    _clearAnnotations();
    notifyListeners();
  }

  Future<bool> saveEditedPdf(BuildContext context) async {
    if (_selectedFile == null || !await _selectedFile!.exists()) return false;

    _isLoading = true;
    _statusMessage = "Applying annotations to PDF...";
    notifyListeners();

    try {
      final Uint8List inputBytes = await _selectedFile!.readAsBytes();

      final Uint8List outputBytes = await compute(
        _exportEditedPdfTask,
        _EditPdfParams(
          inputPath: _selectedFile!.path,
          inputBytes: inputBytes,
          texts: _texts,
          images: _images,
          shapes: _shapes,
          freehandPaths: _freehandPaths,
        ),
      );

      final String fileName = (_selectedFileName != null && _selectedFileName!.isNotEmpty)
          ? 'Edited_${_selectedFileName!}'
          : 'Edited_${DateTime.now().millisecondsSinceEpoch}.pdf';

      final appDir = await getApplicationDocumentsDirectory();
      final String localPdfPath = '${appDir.path}/$fileName';
      final File localPdfFile = File(localPdfPath);
      await localPdfFile.writeAsBytes(outputBytes);

      String? outputPath;
      try {
        outputPath = await FilePicker.saveFile(
          dialogTitle: 'Save Edited PDF',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['pdf'],
          bytes: outputBytes,
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
            await outFile.writeAsBytes(outputBytes);
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
        ).addFile(outputPath, bytes: outputBytes);

        try {
          final openResult = await OpenFilex.open(localPdfPath);
          if (openResult.type != ResultType.done) {
            debugPrint("OpenFilex message: ${openResult.message}");
          }
        } catch (_) {}
      }
      return true;
    } catch (e) {
      debugPrint("Save Edited PDF Error: $e");
      _isLoading = false;
      _statusMessage = "Error saving PDF: $e";
      notifyListeners();
      return false;
    }
  }
}

class _EditPdfParams {
  final String inputPath;
  final Uint8List inputBytes;
  final List<PdfTextAnnotation> texts;
  final List<PdfImageAnnotation> images;
  final List<PdfShapeAnnotation> shapes;
  final List<PdfFreehandPath> freehandPaths;

  const _EditPdfParams({
    required this.inputPath,
    required this.inputBytes,
    required this.texts,
    required this.images,
    required this.shapes,
    required this.freehandPaths,
  });
}

int _countPagesTask(String path) {
  try {
    final File file = File(path);
    final Uint8List bytes = file.readAsBytesSync();
    final PdfDocument document = PdfDocument(inputBytes: bytes);
    final int count = document.pages.count;
    document.dispose();
    return count;
  } catch (_) {
    return 0;
  }
}

Future<Uint8List> _exportEditedPdfTask(_EditPdfParams params) async {
  final document = PdfDocument(inputBytes: params.inputBytes);

  try {
    for (int i = 0; i < document.pages.count; i++) {
      final page = document.pages[i];
      final size = page.size;
      final graphics = page.graphics;

      // 1. Draw Images for this page
      final pageImages = params.images.where((img) => img.pageIndex == i);
      for (final img in pageImages) {
        final pdfImage = PdfBitmap(img.imageBytes);
        final rect = Rect.fromLTWH(
          img.position.dx * size.width,
          img.position.dy * size.height,
          img.size.width * size.width,
          img.size.height * size.height,
        );
        graphics.drawImage(pdfImage, rect);
      }

      // 2. Draw Shapes for this page
      final pageShapes = params.shapes.where((sh) => sh.pageIndex == i);
      for (final shape in pageShapes) {
        final pdfColor = PdfColor(
          (shape.color.r * 255).round(),
          (shape.color.g * 255).round(),
          (shape.color.b * 255).round(),
        );
        final pen = PdfPen(pdfColor, width: shape.strokeWidth);
        final brush = shape.isFilled ? PdfSolidBrush(pdfColor) : null;

        final start = Offset(shape.startPoint.dx * size.width, shape.startPoint.dy * size.height);
        final end = Offset(shape.endPoint.dx * size.width, shape.endPoint.dy * size.height);
        final rect = Rect.fromPoints(start, end);

        if (shape.shapeType == ShapeType.rectangle) {
          graphics.drawRectangle(pen: pen, brush: brush, bounds: rect);
        } else if (shape.shapeType == ShapeType.circle) {
          graphics.drawEllipse(rect, pen: pen, brush: brush);
        } else if (shape.shapeType == ShapeType.line) {
          graphics.drawLine(pen, start, end);
        }
      }

      // 3. Draw Freehand Drawings for this page
      final pagePaths = params.freehandPaths.where((p) => p.pageIndex == i);
      for (final path in pagePaths) {
        if (path.points.length > 1) {
          final pdfColor = PdfColor(
            (path.color.r * 255).round(),
            (path.color.g * 255).round(),
            (path.color.b * 255).round(),
          );
          final pen = PdfPen(pdfColor, width: path.strokeWidth);

          for (int p = 0; p < path.points.length - 1; p++) {
            final p1 = Offset(path.points[p].dx * size.width, path.points[p + 1 - 1].dy * size.height);
            final p2 = Offset(path.points[p + 1].dx * size.width, path.points[p + 1].dy * size.height);
            graphics.drawLine(pen, p1, p2);
          }
        }
      }

      // 4. Draw Text Annotations for this page
      final pageTexts = params.texts.where((t) => t.pageIndex == i);
      for (final textAnn in pageTexts) {
        final pdfColor = PdfColor(
          (textAnn.color.r * 255).round(),
          (textAnn.color.g * 255).round(),
          (textAnn.color.b * 255).round(),
        );
        final font = PdfStandardFont(
          PdfFontFamily.helvetica,
          textAnn.fontSize,
          style: textAnn.isBold ? PdfFontStyle.bold : PdfFontStyle.regular,
        );

        final position = Offset(
          textAnn.position.dx * size.width,
          textAnn.position.dy * size.height,
        );

        final format = PdfStringFormat(lineSpacing: 1.2);
        final textSize = font.measureString(textAnn.text, format: format);

        graphics.drawString(
          textAnn.text,
          font,
          brush: PdfSolidBrush(pdfColor),
          bounds: Rect.fromLTWH(
            position.dx,
            position.dy,
            size.width - position.dx,
            textSize.height * 1.5,
          ),
          format: format,
        );
      }
    }

    final outBytes = await document.save();
    return Uint8List.fromList(outBytes);
  } finally {
    document.dispose();
  }
}
