import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdf_toolkit/provider/pdf_edit_provider/pdf_edit_provider.dart';
import 'package:pdf_toolkit/utils/ad_helper.dart';
import 'package:pdf_toolkit/widgets/banner_ad_widget.dart';
import 'package:pdf_toolkit/widgets/tool_ui_components.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:provider/provider.dart';

class PdfEditScreen extends StatefulWidget {
  const PdfEditScreen({super.key});

  @override
  State<PdfEditScreen> createState() => _PdfEditScreenState();
}

class _PdfEditScreenState extends State<PdfEditScreen> {
  pdfx.PdfDocument? _pdfDocument;
  final Map<int, Future<pdfx.PdfPageImage?>> _pageThumbnailsCache = {};
  Future<void> _renderLock = Future.value();
  final List<Offset> _currentDrawingPoints = [];
  Offset? _shapeStart;
  Offset? _shapeEnd;

  void _loadPdfDocument(String path) async {
    try {
      final oldDoc = _pdfDocument;
      if (mounted) {
        setState(() {
          _pageThumbnailsCache.clear();
          _renderLock = Future.value();
          _pdfDocument = null;
        });
      }
      if (oldDoc != null) {
        await oldDoc.close();
      }
      final doc = await pdfx.PdfDocument.openFile(path);
      if (mounted) {
        setState(() {
          _pdfDocument = doc;
        });
      }
    } catch (e) {
      debugPrint("Error loading pdf in editor: $e");
    }
  }

  Future<pdfx.PdfPageImage?> _getPageImage(int pageNum) {
    if (_pageThumbnailsCache.containsKey(pageNum)) {
      return _pageThumbnailsCache[pageNum]!;
    }

    final future = _renderLock.then((_) async {
      if (_pdfDocument == null) return null;
      pdfx.PdfPage? page;
      try {
        page = await _pdfDocument!.getPage(pageNum);
        final double aspectRatio = page.width / page.height;
        final int targetWidth = 800;
        final int targetHeight = (targetWidth / aspectRatio).round();

        final image = await page.render(
          width: targetWidth.toDouble(),
          height: targetHeight.toDouble(),
          format: pdfx.PdfPageImageFormat.jpeg,
        );
        return image;
      } catch (e) {
        return null;
      } finally {
        await page?.close();
      }
    });

    _renderLock = future.then((_) {});
    _pageThumbnailsCache[pageNum] = future;
    return future;
  }

  @override
  void dispose() {
    _pdfDocument?.close();
    super.dispose();
  }

  void _showAddTextDialog(BuildContext context, PdfEditProvider provider, Offset normalizedPos) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add Text Annotation"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: textController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: "Enter text...",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () {
              if (textController.text.trim().isNotEmpty) {
                provider.addText(textController.text.trim(), normalizedPos);
                Navigator.pop(ctx);
              }
            },
            child: const Text("Add Text"),
          ),
        ],
      ),
    );
  }

  void _pickAndAddImage(PdfEditProvider provider, Offset normalizedPos) async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.image);
      if (result != null && result.files.single.path != null) {
        final bytes = await File(result.files.single.path!).readAsBytes();
        provider.addImage(bytes, normalizedPos, const Size(0.3, 0.2));
      }
    } catch (e) {
      debugPrint("Image pick error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<PdfEditProvider>(
      builder: (context, provider, child) {
        final hasFile = provider.selectedFile != null;

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: const ToolAppBar(),
          body: Column(
            children: [
              Expanded(
                child: !hasFile
                    ? SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ToolHeader(
                              title: "Edit PDF",
                              subtitle: "Add text, images, shapes, and freehand annotations.",
                              icon: Icons.edit_note_rounded,
                              color: Colors.purple[700]!,
                            ),
                            const SectionHeader(title: "Select PDF to Edit"),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              child: InkWell(
                                onTap: provider.isLoading
                                    ? null
                                    : () async {
                                        bool success = await provider.pickFile();
                                        if (success && provider.selectedFile != null) {
                                          _loadPdfDocument(provider.selectedFile!.path);
                                        }
                                      },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: theme.cardColor,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: theme.dividerColor),
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.add_circle_outline_rounded,
                                          color: theme.colorScheme.primary,
                                          size: 32,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          "Tap to select a PDF document",
                                          style: TextStyle(color: theme.hintColor),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          // Annotation Editing Toolbar
                          _buildEditingToolbar(context, provider, theme),

                          // Interactive PDF Page Canvas
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final currentPageNum = provider.currentPageIndex + 1;
                                  return GestureDetector(
                                    onPanStart: (details) {
                                      final RenderBox box = context.findRenderObject() as RenderBox;
                                      final localPos = box.globalToLocal(details.globalPosition);
                                      final normX = (localPos.dx / constraints.maxWidth).clamp(0.0, 1.0);
                                      final normY = (localPos.dy / constraints.maxHeight).clamp(0.0, 1.0);

                                      if (provider.activeTool == EditTool.freehand) {
                                        setState(() {
                                          _currentDrawingPoints.clear();
                                          _currentDrawingPoints.add(Offset(normX, normY));
                                        });
                                      } else if (provider.activeTool == EditTool.shape) {
                                        setState(() {
                                          _shapeStart = Offset(normX, normY);
                                          _shapeEnd = Offset(normX, normY);
                                        });
                                      }
                                    },
                                    onPanUpdate: (details) {
                                      final RenderBox box = context.findRenderObject() as RenderBox;
                                      final localPos = box.globalToLocal(details.globalPosition);
                                      final normX = (localPos.dx / constraints.maxWidth).clamp(0.0, 1.0);
                                      final normY = (localPos.dy / constraints.maxHeight).clamp(0.0, 1.0);

                                      if (provider.activeTool == EditTool.freehand) {
                                        setState(() {
                                          _currentDrawingPoints.add(Offset(normX, normY));
                                        });
                                      } else if (provider.activeTool == EditTool.shape) {
                                        setState(() {
                                          _shapeEnd = Offset(normX, normY);
                                        });
                                      }
                                    },
                                    onPanEnd: (details) {
                                      if (provider.activeTool == EditTool.freehand) {
                                        if (_currentDrawingPoints.isNotEmpty) {
                                          provider.addFreehandPath(_currentDrawingPoints);
                                          setState(() {
                                            _currentDrawingPoints.clear();
                                          });
                                        }
                                      } else if (provider.activeTool == EditTool.shape) {
                                        if (_shapeStart != null && _shapeEnd != null) {
                                          provider.addShape(
                                            provider.activeShapeType,
                                            _shapeStart!,
                                            _shapeEnd!,
                                          );
                                          setState(() {
                                            _shapeStart = null;
                                            _shapeEnd = null;
                                          });
                                        }
                                      }
                                    },
                                    onTapUp: (details) {
                                      final RenderBox box = context.findRenderObject() as RenderBox;
                                      final localPos = box.globalToLocal(details.globalPosition);
                                      final normX = (localPos.dx / constraints.maxWidth).clamp(0.0, 1.0);
                                      final normY = (localPos.dy / constraints.maxHeight).clamp(0.0, 1.0);
                                      final normPos = Offset(normX, normY);

                                      if (provider.activeTool == EditTool.text) {
                                        _showAddTextDialog(context, provider, normPos);
                                      } else if (provider.activeTool == EditTool.image) {
                                        _pickAndAddImage(provider, normPos);
                                      }
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: const [
                                          BoxShadow(color: Colors.black12, blurRadius: 8),
                                        ],
                                      ),
                                      child: Stack(
                                        children: [
                                          // Background Rendered PDF Page Image
                                          Positioned.fill(
                                            child: _pdfDocument != null
                                                ? FutureBuilder<pdfx.PdfPageImage?>(
                                                    future: _getPageImage(currentPageNum),
                                                    builder: (context, snapshot) {
                                                      if (snapshot.hasData && snapshot.data != null) {
                                                        return Image.memory(
                                                          snapshot.data!.bytes,
                                                          fit: BoxFit.contain,
                                                        );
                                                      }
                                                      return const Center(
                                                        child: CircularProgressIndicator(strokeWidth: 2),
                                                      );
                                                    },
                                                  )
                                                : const Center(
                                                    child: Icon(Icons.picture_as_pdf_rounded, size: 64, color: Colors.grey),
                                                  ),
                                          ),

                                          // Custom Overlay Painter for Text, Shapes, Freehand
                                          Positioned.fill(
                                            child: CustomPaint(
                                              painter: _AnnotationPainter(
                                                provider: provider,
                                                currentPageIndex: provider.currentPageIndex,
                                                currentDrawingPoints: _currentDrawingPoints,
                                                shapeStart: _shapeStart,
                                                shapeEnd: _shapeEnd,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),

                          // Page Selector Controller
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            color: theme.cardColor,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
                                  onPressed: provider.currentPageIndex > 0
                                      ? () => provider.setCurrentPageIndex(provider.currentPageIndex - 1)
                                      : null,
                                ),
                                Text(
                                  "Page ${provider.currentPageIndex + 1} of ${provider.totalPages}",
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                                  onPressed: provider.currentPageIndex < provider.totalPages - 1
                                      ? () => provider.setCurrentPageIndex(provider.currentPageIndex + 1)
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),

              if (hasFile && !provider.isLoading)
                BottomActionBar(
                  actionText: "Save Edited PDF",
                  isLoading: provider.isLoading,
                  color: Colors.purple[700]!,
                  onAction: () async {
                    final success = await provider.saveEditedPdf(context);
                    if (!context.mounted) return;
                    if (provider.statusMessage != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(provider.statusMessage!)),
                      );
                    }
                    if (success) {
                      AdHelper.showInterstitialAd(() {});
                    }
                  },
                ),
              if (!hasFile) const BannerAdWidget(placement: AdPlacement.tools),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEditingToolbar(BuildContext context, PdfEditProvider provider, ThemeData theme) {
    return Container(
      color: theme.cardColor,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _toolButton(provider, EditTool.pointer, Icons.touch_app_rounded, "Pointer"),
              _toolButton(provider, EditTool.text, Icons.text_fields_rounded, "Text"),
              _toolButton(provider, EditTool.image, Icons.image_rounded, "Image"),
              _toolButton(provider, EditTool.shape, Icons.category_rounded, "Shape"),
              _toolButton(provider, EditTool.freehand, Icons.draw_rounded, "Draw"),
              IconButton(
                icon: const Icon(Icons.undo_rounded, color: Colors.amber),
                tooltip: "Undo Last",
                onPressed: () => provider.undoLastAnnotation(),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                tooltip: "Clear Page",
                onPressed: () => provider.clearPageAnnotations(),
              ),
            ],
          ),

          // Sub-options bar for Tool settings
          if (provider.activeTool == EditTool.shape) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text("Rectangle"),
                  selected: provider.activeShapeType == ShapeType.rectangle,
                  onSelected: (_) => provider.setActiveShapeType(ShapeType.rectangle),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text("Circle"),
                  selected: provider.activeShapeType == ShapeType.circle,
                  onSelected: (_) => provider.setActiveShapeType(ShapeType.circle),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text("Line"),
                  selected: provider.activeShapeType == ShapeType.line,
                  onSelected: (_) => provider.setActiveShapeType(ShapeType.line),
                ),
              ],
            ),
          ],

          // Color Palette Bar
          if (provider.activeTool != EditTool.pointer) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Text("Color: ", style: TextStyle(fontSize: 12)),
                  for (final color in [
                    Colors.red,
                    Colors.blue,
                    Colors.green,
                    Colors.amber,
                    Colors.purple,
                    Colors.black,
                    Colors.white,
                  ])
                    GestureDetector(
                      onTap: () => provider.setActiveColor(color),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: provider.activeColor == color ? Colors.purple : Colors.grey,
                            width: provider.activeColor == color ? 2.5 : 1,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 16),
                  if (provider.activeTool == EditTool.text) ...[
                    const Text("Size: ", style: TextStyle(fontSize: 12)),
                    Slider(
                      value: provider.activeFontSize,
                      min: 12,
                      max: 36,
                      divisions: 12,
                      label: provider.activeFontSize.round().toString(),
                      onChanged: (val) => provider.setActiveFontSize(val),
                    ),
                  ],
                  if (provider.activeTool == EditTool.freehand || provider.activeTool == EditTool.shape) ...[
                    const Text("Thickness: ", style: TextStyle(fontSize: 12)),
                    Slider(
                      value: provider.activeStrokeWidth,
                      min: 1,
                      max: 10,
                      divisions: 9,
                      label: provider.activeStrokeWidth.round().toString(),
                      onChanged: (val) => provider.setActiveStrokeWidth(val),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _toolButton(PdfEditProvider provider, EditTool tool, IconData icon, String label) {
    final isSelected = provider.activeTool == tool;
    return InkWell(
      onTap: () => provider.setActiveTool(tool),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.purple.withAlpha(30) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? Colors.purple : Colors.transparent),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.purple : Colors.grey, size: 20),
            Text(label, style: TextStyle(fontSize: 10, color: isSelected ? Colors.purple : Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _AnnotationPainter extends CustomPainter {
  final PdfEditProvider provider;
  final int currentPageIndex;
  final List<Offset> currentDrawingPoints;
  final Offset? shapeStart;
  final Offset? shapeEnd;

  _AnnotationPainter({
    required this.provider,
    required this.currentPageIndex,
    required this.currentDrawingPoints,
    this.shapeStart,
    this.shapeEnd,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Images
    final pageImages = provider.images.where((img) => img.pageIndex == currentPageIndex);
    for (final img in pageImages) {
      final rect = Rect.fromLTWH(
        img.position.dx * size.width,
        img.position.dy * size.height,
        img.size.width * size.width,
        img.size.height * size.height,
      );
      canvas.drawRect(rect, Paint()..color = Colors.purple.withAlpha(40)..style = PaintingStyle.fill);
      canvas.drawRect(rect, Paint()..color = Colors.purple..style = PaintingStyle.stroke..strokeWidth = 1);
    }

    // 2. Draw Saved Shapes
    final pageShapes = provider.shapes.where((s) => s.pageIndex == currentPageIndex);
    for (final shape in pageShapes) {
      final paint = Paint()
        ..color = shape.color
        ..strokeWidth = shape.strokeWidth
        ..style = shape.isFilled ? PaintingStyle.fill : PaintingStyle.stroke;

      final start = Offset(shape.startPoint.dx * size.width, shape.startPoint.dy * size.height);
      final end = Offset(shape.endPoint.dx * size.width, shape.endPoint.dy * size.height);
      final rect = Rect.fromPoints(start, end);

      if (shape.shapeType == ShapeType.rectangle) {
        canvas.drawRect(rect, paint);
      } else if (shape.shapeType == ShapeType.circle) {
        canvas.drawOval(rect, paint);
      } else if (shape.shapeType == ShapeType.line) {
        canvas.drawLine(start, end, paint);
      }
    }

    // 3. Draw Active Shape preview
    if (shapeStart != null && shapeEnd != null) {
      final paint = Paint()
        ..color = provider.activeColor
        ..strokeWidth = provider.activeStrokeWidth
        ..style = PaintingStyle.stroke;

      final start = Offset(shapeStart!.dx * size.width, shapeStart!.dy * size.height);
      final end = Offset(shapeEnd!.dx * size.width, shapeEnd!.dy * size.height);
      final rect = Rect.fromPoints(start, end);

      if (provider.activeShapeType == ShapeType.rectangle) {
        canvas.drawRect(rect, paint);
      } else if (provider.activeShapeType == ShapeType.circle) {
        canvas.drawOval(rect, paint);
      } else if (provider.activeShapeType == ShapeType.line) {
        canvas.drawLine(start, end, paint);
      }
    }

    // 4. Draw Saved Freehand Paths
    final pagePaths = provider.freehandPaths.where((p) => p.pageIndex == currentPageIndex);
    for (final path in pagePaths) {
      if (path.points.length > 1) {
        final paint = Paint()
          ..color = path.color
          ..strokeWidth = path.strokeWidth
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

        for (int i = 0; i < path.points.length - 1; i++) {
          final p1 = Offset(path.points[i].dx * size.width, path.points[i].dy * size.height);
          final p2 = Offset(path.points[i + 1].dx * size.width, path.points[i + 1].dy * size.height);
          canvas.drawLine(p1, p2, paint);
        }
      }
    }

    // 5. Draw Active Freehand Drawing
    if (currentDrawingPoints.length > 1) {
      final paint = Paint()
        ..color = provider.activeColor
        ..strokeWidth = provider.activeStrokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      for (int i = 0; i < currentDrawingPoints.length - 1; i++) {
        final p1 = Offset(currentDrawingPoints[i].dx * size.width, currentDrawingPoints[i].dy * size.height);
        final p2 = Offset(currentDrawingPoints[i + 1].dx * size.width, currentDrawingPoints[i + 1].dy * size.height);
        canvas.drawLine(p1, p2, paint);
      }
    }

    // 6. Draw Text Annotations
    final pageTexts = provider.texts.where((t) => t.pageIndex == currentPageIndex);
    for (final textAnn in pageTexts) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: textAnn.text,
          style: TextStyle(
            color: textAnn.color,
            fontSize: textAnn.fontSize,
            fontWeight: textAnn.isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      final pos = Offset(
        textAnn.position.dx * size.width,
        textAnn.position.dy * size.height,
      );
      textPainter.paint(canvas, pos);
    }
  }

  @override
  bool shouldRepaint(covariant _AnnotationPainter oldDelegate) => true;
}
