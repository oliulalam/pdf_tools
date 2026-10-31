import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:pdf_toolkit/provider/pdf_to_image_provider/pdf_to_image_provider.dart';
import 'package:pdf_toolkit/utils/ad_helper.dart';
import 'package:pdf_toolkit/widgets/banner_ad_widget.dart';
import 'package:pdf_toolkit/widgets/tool_ui_components.dart';
import 'package:provider/provider.dart';

class PdfToImageHomeScreen extends StatefulWidget {
  const PdfToImageHomeScreen({super.key});

  @override
  State<PdfToImageHomeScreen> createState() => _PdfToImageHomeScreenState();
}

class _PdfToImageHomeScreenState extends State<PdfToImageHomeScreen> {
  // Local state for UI options since provider only holds file paths and progress
  PdfPageImageFormat _selectedFormat = PdfPageImageFormat.jpeg;
  double _renderScale = 2.0;

  Future<void> _picker(PdfToImageProvider provider) async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        await provider.setPdf(
          result.files.single.path,
          result.files.single.name,
        );
      }
    } catch (e) {
      if (mounted) {
        Fluttertoast.showToast(
          msg: "Error picking PDF: $e",
          backgroundColor: Colors.red,
        );
      }
    }
  }

  Future<bool> _convertToImages(PdfToImageProvider provider) async {
    if (provider.pdfPath == null) return false;

    // Step 1: Get total page count
    int totalPages = 0;
    try {
      final tempDoc = await PdfDocument.openFile(provider.pdfPath!);
      totalPages = tempDoc.pagesCount;
      await tempDoc.close();
    } catch (e) {
      if (mounted) {
        Fluttertoast.showToast(
          msg: "Could not read PDF: $e",
          backgroundColor: Colors.red,
        );
      }
      return false;
    }

    provider.setConverting(true);

    try {
      final tempDir = await getTemporaryDirectory();
      final sessionPath =
          '${tempDir.path}/pdf_img_${DateTime.now().millisecondsSinceEpoch}';
      final sessionDir = Directory(sessionPath);
      await sessionDir.create(recursive: true);

      final document = await PdfDocument.openFile(provider.pdfPath!);

      for (int i = 1; i <= totalPages; i++) {
        if (!mounted) break;

        provider.updateProgress(i, totalPages);
        provider.setStatus("Converting page $i of $totalPages...");

        final page = await document.getPage(i);
        final img = await page.render(
          width: page.width * _renderScale,
          height: page.height * _renderScale,
          format: _selectedFormat,
          backgroundColor: _selectedFormat == PdfPageImageFormat.png
              ? null
              : '#FFFFFF',
        );

        if (img != null) {
          final ext = _selectedFormat == PdfPageImageFormat.png ? 'png' : 'jpg';
          final filePath =
              '$sessionPath/page_${i.toString().padLeft(4, '0')}.$ext';
          final file = File(filePath);
          await file.writeAsBytes(img.bytes);

          provider.addImage(filePath);
        }
        await page.close();
      }
      await document.close();
      provider.setStatus('');
      return true;
    } catch (e) {
      if (mounted) {
        Fluttertoast.showToast(
          msg: "Conversion failed: $e",
          backgroundColor: Colors.red,
          gravity: ToastGravity.CENTER,
        );
      }
      return false;
    } finally {
      provider.setConverting(false);
      provider.setStatus('');
    }
  }

  Future<bool> _saveAsZip(PdfToImageProvider provider) async {
    if (provider.pageImages.isEmpty) return false;

    provider.setZipping(true);

    try {
      final tempDir = await getTemporaryDirectory();
      final workingDir = Directory(
        '${tempDir.path}/zip_out_${DateTime.now().millisecondsSinceEpoch}',
      );
      await workingDir.create(recursive: true);

      final tempZipPath = '${workingDir.path}/images.zip';

      final encoder = ZipFileEncoder();
      encoder.create(tempZipPath);

      for (final imagePath in provider.pageImages) {
        final file = File(imagePath);
        if (await file.exists()) {
          encoder.addFile(file);
        }
      }
      encoder.close();

      final sourceZip = File(tempZipPath);
      final zipBytes = await sourceZip.readAsBytes();

      final String? outputPath = await FilePicker.saveFile(
        dialogTitle: 'Select where you want to save',
        fileName: 'pdf_to_images_${DateTime.now().millisecondsSinceEpoch}.zip',
        type: FileType.custom,
        allowedExtensions: ['zip'],
        bytes: zipBytes,
      );

      if (outputPath == null) {
        if (await workingDir.exists()) await workingDir.delete(recursive: true);
        return false;
      }
      
      if (await workingDir.exists()) await workingDir.delete(recursive: true);
      return true;
    } catch (e) {
      debugPrint("Error in _saveAsZip: $e");
      if (mounted) {
        Fluttertoast.showToast(
          msg: "Error: $e",
          backgroundColor: Colors.red,
          gravity: ToastGravity.CENTER,
        );
      }
      return false;
    } finally {
      provider.setZipping(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: const ToolAppBar(),
      body: Consumer<PdfToImageProvider>(
        builder: (context, provider, child) {
          final hasFile = provider.hasPdf;
          final hasImages = provider.hasImages;

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ToolHeader(
                        title: "PDF to Images",
                        subtitle: "Save each page as a crisp image.",
                        icon: Icons.insert_drive_file_outlined,
                        color: Colors.orangeAccent,
                      ),

                      const SectionHeader(title: "Selected document"),
                      if (hasFile)
                        SelectedFileCard(
                          file: File(provider.pdfPath!),
                          overrideName: provider.pdfName,
                          onChange: provider.isConverting
                              ? null
                              : () => _picker(provider),
                          badgeColor: Colors.orangeAccent,
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          child: InkWell(
                            onTap: provider.isConverting
                                ? null
                                : () => _picker(provider),
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
                                      Icons.add_circle_outline_rounded,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      "Tap to select a PDF",
                                      style: TextStyle(color: theme.hintColor),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                      if (hasFile && !hasImages) ...[
                        const SectionHeader(
                          title: "Image settings",
                          trailingText: "Choose output",
                        ),
                        _buildFormatSelection(theme, isDark),
                        const SizedBox(height: 16),
                        _buildQualitySelection(theme, isDark),
                      ],

                      if (provider.isConverting) ...[
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: LinearProgressIndicator(
                            color: Colors.orangeAccent,
                            value: provider.progressValue,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            provider.statusMessage.isNotEmpty
                                ? provider.statusMessage
                                : "Converting...",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.hintColor,
                            ),
                          ),
                        ),
                      ],

                      if (hasImages) ...[
                        SectionHeader(
                          title: "Output preview",
                          trailingText: "${provider.pageImages.length} images",
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Container(
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: theme.dividerColor.withAlpha(20),
                              ),
                            ),
                            child: GridView.builder(
                              padding: const EdgeInsets.all(12),
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8,
                                    childAspectRatio: 0.75,
                                  ),
                              itemCount: provider.pageImages.length > 9
                                  ? 9
                                  : provider
                                        .pageImages
                                        .length, // Show up to 9 for preview
                              itemBuilder: (context, index) {
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    File(provider.pageImages[index]),
                                    fit: BoxFit.cover,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
              if (hasFile && !hasImages)
                BottomActionBar(
                  actionText: "Convert Pages",
                  isLoading: provider.isConverting,
                  color: Colors.orangeAccent,
                  onAction: () => _convertToImages(provider),
                ),
              if (hasImages)
                BottomActionBar(
                  actionText: "Download ZIP",
                  isLoading: provider.isZipping,
                  color: Colors.orangeAccent,
                  onAction: () async {
                    final success = await _saveAsZip(provider);
                    if (success) {
                      AdHelper.showInterstitialAd(() {});
                    }
                  },
                ),
              if (!hasFile) const BannerAdWidget(placement: AdPlacement.tools),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFormatSelection(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "File format",
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
                child: _buildFormatCard(
                  theme: theme,
                  isDark: isDark,
                  label: "JPG",
                  desc: "Smaller files",
                  isSelected: _selectedFormat == PdfPageImageFormat.jpeg,
                  onTap: () =>
                      setState(() => _selectedFormat = PdfPageImageFormat.jpeg),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFormatCard(
                  theme: theme,
                  isDark: isDark,
                  label: "PNG",
                  desc: "Transparent-ready",
                  isSelected: _selectedFormat == PdfPageImageFormat.png,
                  onTap: () =>
                      setState(() => _selectedFormat = PdfPageImageFormat.png),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormatCard({
    required ThemeData theme,
    required bool isDark,
    required String label,
    required String desc,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Colors.orangeAccent
                : theme.dividerColor.withAlpha(20),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: Colors.orangeAccent.withAlpha(20),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    desc,
                    style: TextStyle(fontSize: 10, color: theme.hintColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.orangeAccent,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQualitySelection(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Image quality",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: theme.hintColor,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor.withAlpha(20)),
            ),
            child: Row(
              children: [
                Expanded(child: _buildQualityPill(theme, "Smaller", 1.0)),
                Expanded(child: _buildQualityPill(theme, "Balanced", 2.0)),
                Expanded(child: _buildQualityPill(theme, "Best", 3.0)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Good detail, balanced size",
                style: TextStyle(fontSize: 11, color: theme.hintColor),
              ),
              Text(
                _renderScale == 1.0
                    ? "50%"
                    : (_renderScale == 2.0 ? "78%" : "100%"),
                style: TextStyle(fontSize: 11, color: theme.hintColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQualityPill(ThemeData theme, String label, double scale) {
    final isSelected = _renderScale == scale;
    return GestureDetector(
      onTap: () => setState(() => _renderScale = scale),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.scaffoldBackgroundColor
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.orangeAccent : Colors.transparent,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.orangeAccent : theme.hintColor,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
