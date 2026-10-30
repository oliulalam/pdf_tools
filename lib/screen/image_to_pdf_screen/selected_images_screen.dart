import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'; // For compute
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/pdf.dart' as pw;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf_toolkit/provider/file_history_provider.dart';
import 'package:pdf_toolkit/provider/image_to_pdf_provider/images_to_pdf_provider.dart';
import 'package:pdf_toolkit/utils/ad_helper.dart';
import 'package:pdf_toolkit/widgets/banner_ad_widget.dart';
import 'package:pdf_toolkit/widgets/tool_ui_components.dart';
import 'package:provider/provider.dart';
import 'package:open_filex/open_filex.dart';

class PdfTaskConfig {
  final List<String> paths;
  final PageSizeOption pageSize;
  final PageOrientationOption orientation;

  PdfTaskConfig({
    required this.paths,
    required this.pageSize,
    required this.orientation,
  });
}

class SelectedImagesScreen extends StatefulWidget {
  const SelectedImagesScreen({super.key});

  @override
  State<SelectedImagesScreen> createState() => _SelectedImagesScreenState();
}

class _SelectedImagesScreenState extends State<SelectedImagesScreen> {
  bool _isConverting = false;

  Future<void> _createAndSavePdf() async {
    final provider = Provider.of<ImagesProvider>(context, listen: false);
    if (provider.images.isEmpty) return;

    setState(() {
      _isConverting = true;
    });

    try {
      final List<String> imagePaths = provider.images
          .map((img) => img.path)
          .toList();
      final config = PdfTaskConfig(
        paths: imagePaths,
        pageSize: provider.pageSize,
        orientation: provider.orientation,
      );

      final Uint8List bytes = await compute(generatePdfFromPathsTask, config);

      final String? outputPath = await FilePicker.saveFile(
        dialogTitle: 'Select Save Location',
        fileName: 'Document_${DateTime.now().millisecondsSinceEpoch}.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: bytes,
      );

      if (mounted) {
        setState(() {
          _isConverting = false;
        });

        if (outputPath != null) {
          context.read<FileHistoryProvider>().addFile(outputPath);
          provider.clearImages();

          AdHelper.showInterstitialAd(() {
            if (mounted) {
              OpenFilex.open(outputPath);
              Navigator.pop(context);
            }
          });
        }
      }
    } catch (e) {
      debugPrint("PDF Generation Error: $e");
      if (mounted) {
        setState(() => _isConverting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Generation Failed: $e")));
      }
    }
  }

  Future<void> _addMorePhotos(ImagesProvider provider) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickMultiImage();
      if (picked.isNotEmpty) {
        provider.addImages(picked);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: const ToolAppBar(),
      body: Consumer<ImagesProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ToolHeader(
                        title: "Images to PDF",
                        subtitle:
                            "Arrange your photos, then choose a page layout.",
                        icon: Icons.photo_library_rounded,
                        color: Colors.blueAccent,
                      ),

                      SectionHeader(
                        title: "Selected photos",
                        trailingText: "${provider.count} photos",
                      ),

                      if (provider.hasImages)
                        ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          itemCount: provider.count,
                          itemBuilder: (context, index) {
                            return _buildPhotoListItem(
                              context,
                              theme,
                              isDark,
                              provider,
                              index,
                            );
                          },
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          child: InkWell(
                            onTap: () => _addMorePhotos(provider),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              height: 100,
                              decoration: BoxDecoration(
                                color: theme.cardColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: theme.dividerColor,
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_photo_alternate_rounded,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      "Tap to select photos",
                                      style: TextStyle(color: theme.hintColor),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                      if (provider.hasImages)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          child: OutlinedButton.icon(
                            onPressed: () => _addMorePhotos(provider),
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: const Text("Add photos"),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            side: BorderSide(
                              color: theme.dividerColor,
                              style: BorderStyle.solid,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            foregroundColor: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),

                      const SectionHeader(
                        title: "Page setup",
                        trailingText: "For every photo",
                      ),

                      _buildPageSetupCard(theme, isDark, provider),

                      if (_isConverting) ...[
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: LinearProgressIndicator(
                            color: Colors.blueAccent,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            "Generating PDF...",
                            style: TextStyle(
                              color: theme.hintColor,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
              if (provider.hasImages)
                BottomActionBar(
                  actionText: "Create PDF",
                  isLoading: _isConverting,
                  color: Colors.blueAccent,
                  onAction: _createAndSavePdf,
                ),
              if (!provider.hasImages) const BannerAdWidget(placement: AdPlacement.tools),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPhotoListItem(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    ImagesProvider provider,
    int index,
  ) {
    final file = File(provider.images[index].path);
    final name = file.path.split(Platform.pathSeparator).last;

    String sizeText = "Unknown size";
    try {
      if (file.existsSync()) {
        sizeText =
            "${(file.lengthSync() / (1024 * 1024)).toStringAsFixed(1)} MB";
      }
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withAlpha(20)),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  Image.file(file, width: 60, height: 60, fit: BoxFit.cover),
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "${index + 1}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  sizeText,
                  style: TextStyle(fontSize: 11, color: theme.hintColor),
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_upward_rounded, size: 16),
                visualDensity: VisualDensity.compact,
                color: index > 0
                    ? theme.colorScheme.onSurface
                    : theme.dividerColor,
                onPressed: index > 0 ? () => provider.moveImageUp(index) : null,
              ),
              IconButton(
                icon: const Icon(Icons.arrow_downward_rounded, size: 16),
                visualDensity: VisualDensity.compact,
                color: index < provider.count - 1
                    ? theme.colorScheme.onSurface
                    : theme.dividerColor,
                onPressed: index < provider.count - 1
                    ? () => provider.moveImageDown(index)
                    : null,
              ),
            ],
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.redAccent,
              size: 20,
            ),
            onPressed: () => provider.removedImage(index),
          ),
        ],
      ),
    );
  }

  Widget _buildPageSetupCard(
    ThemeData theme,
    bool isDark,
    ImagesProvider provider,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withAlpha(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Page size",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: theme.hintColor,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildPillSelection(
                theme: theme,
                label: "A4",
                isSelected: provider.pageSize == PageSizeOption.a4,
                onTap: () => provider.setPageSize(PageSizeOption.a4),
              ),
              const SizedBox(width: 8),
              _buildPillSelection(
                theme: theme,
                label: "Letter",
                isSelected: provider.pageSize == PageSizeOption.letter,
                onTap: () => provider.setPageSize(PageSizeOption.letter),
              ),
              const SizedBox(width: 8),
              _buildPillSelection(
                theme: theme,
                label: "Fit image",
                isSelected: provider.pageSize == PageSizeOption.fitImage,
                onTap: () => provider.setPageSize(PageSizeOption.fitImage),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Opacity(
            opacity: provider.pageSize == PageSizeOption.fitImage ? 0.5 : 1.0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Orientation",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.hintColor,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildOrientationSelection(
                        theme: theme,
                        icon: Icons.crop_portrait_rounded,
                        label: "Portrait",
                        isSelected:
                            provider.orientation == PageOrientationOption.portrait,
                        onTap: provider.pageSize == PageSizeOption.fitImage ? () {} : () =>
                            provider.setOrientation(PageOrientationOption.portrait),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildOrientationSelection(
                        theme: theme,
                        icon: Icons.crop_landscape_rounded,
                        label: "Landscape",
                        isSelected:
                            provider.orientation == PageOrientationOption.landscape,
                        onTap: provider.pageSize == PageSizeOption.fitImage ? () {} : () =>
                            provider.setOrientation(PageOrientationOption.landscape),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillSelection({
    required ThemeData theme,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blueAccent.withAlpha(20)
              : theme.scaffoldBackgroundColor,
          border: Border.all(
            color: isSelected ? Colors.blueAccent : theme.dividerColor,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.blueAccent : theme.colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildOrientationSelection({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blueAccent.withAlpha(20)
              : theme.scaffoldBackgroundColor,
          border: Border.all(
            color: isSelected ? Colors.blueAccent : theme.dividerColor,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.blueAccent : theme.hintColor,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.blueAccent
                    : theme.colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Top-level function for PDF generation to be used with compute
Future<Uint8List> generatePdfFromPathsTask(PdfTaskConfig config) async {
  final pdf = pw.Document();

  // Determine base page format
  pw.PdfPageFormat baseFormat = pw.PdfPageFormat.a4;
  if (config.pageSize == PageSizeOption.letter) {
    baseFormat = pw.PdfPageFormat.letter;
  }

  if (config.orientation == PageOrientationOption.landscape) {
    baseFormat = baseFormat.landscape;
  }

  for (final path in config.paths) {
    final file = File(path);
    if (!file.existsSync()) continue;

    final bytes = file.readAsBytesSync();
    final image = pw.MemoryImage(bytes);

    if (config.pageSize == PageSizeOption.fitImage) {
      // Fit to image dimensions
      final double w = (image.width ?? 595).toDouble();
      final double h = (image.height ?? 842).toDouble();
      pdf.addPage(
        pw.Page(
          pageFormat: pw.PdfPageFormat(w, h),
          margin: pw.EdgeInsets.zero,
          build: (pw.Context context) =>
              pw.FullPage(ignoreMargins: true, child: pw.Image(image)),
        ),
      );
    } else {
      pdf.addPage(
        pw.Page(
          pageFormat: baseFormat,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) => pw.Center(
            child: pw.FittedBox(fit: pw.BoxFit.contain, child: pw.Image(image)),
          ),
        ),
      );
    }
  }
  return await pdf.save();
}
