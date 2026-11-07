import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:pdf_toolkit/provider/pdf_organize_provider/pdf_organize_provider.dart';
import 'package:pdf_toolkit/utils/ad_helper.dart';
import 'package:pdf_toolkit/widgets/banner_ad_widget.dart';
import 'package:pdf_toolkit/widgets/tool_ui_components.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:provider/provider.dart';

class PdfOrganizeScreen extends StatefulWidget {
  const PdfOrganizeScreen({super.key});

  @override
  State<PdfOrganizeScreen> createState() => _PdfOrganizeScreenState();
}

class _PdfOrganizeScreenState extends State<PdfOrganizeScreen> {
  pdfx.PdfDocument? _pdfDocument;
  final Map<int, Future<pdfx.PdfPageImage?>> _pageThumbnailsCache = {};
  Future<void> _renderLock = Future.value();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<PdfOrganizeProvider>();
      if (provider.selectedFile != null) {
        _loadPdfDocument(provider.selectedFile!.path);
      }
    });
  }

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
      debugPrint("Error loading pdf thumbnail: $e");
    }
  }

  Future<pdfx.PdfPageImage?> _getPageThumbnail(int pageNum) {
    if (_pageThumbnailsCache.containsKey(pageNum)) {
      return _pageThumbnailsCache[pageNum]!;
    }

    final future = _renderLock.then((_) async {
      if (_pdfDocument == null) return null;
      pdfx.PdfPage? page;
      try {
        page = await _pdfDocument!.getPage(pageNum);
        final double aspectRatio = page.width / page.height;
        final int targetWidth = 100;
        final int targetHeight =
            (targetWidth / aspectRatio).round().clamp(60, 140);

        final image = await page.render(
          width: targetWidth.toDouble(),
          height: targetHeight.toDouble(),
          format: pdfx.PdfPageImageFormat.jpeg,
        );
        return image;
      } catch (e) {
        debugPrint("Error rendering thumbnail for page $pageNum: $e");
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<PdfOrganizeProvider>(
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
                            const ToolHeader(
                              title: "Organize PDF",
                              subtitle: "Rotate, reorder, and delete pages.",
                              icon: Icons.dashboard_customize_rounded,
                              color: Colors.amber,
                            ),
                            const SectionHeader(title: "Selected PDF"),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 8),
                              child: InkWell(
                                onTap: provider.isLoading
                                    ? null
                                    : () async {
                                        bool success = await provider.pickFile();
                                        if (success &&
                                            provider.selectedFile != null) {
                                          _loadPdfDocument(
                                              provider.selectedFile!.path);
                                        }
                                      },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  height: 100,
                                  decoration: BoxDecoration(
                                    color: theme.cardColor,
                                    borderRadius: BorderRadius.circular(16),
                                    border:
                                        Border.all(color: theme.dividerColor),
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.add_circle_outline_rounded,
                                          color: theme.colorScheme.primary,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          "Tap to select a PDF",
                                          style:
                                              TextStyle(color: theme.hintColor),
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
                    : Theme(
                        data: Theme.of(context).copyWith(
                          canvasColor: Colors.transparent,
                        ),
                        child: ReorderableListView.builder(
                          padding: const EdgeInsets.only(bottom: 24),
                          header: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const ToolHeader(
                                title: "Organize PDF",
                                subtitle: "Rotate, reorder, and delete pages.",
                                icon: Icons.dashboard_customize_rounded,
                                color: Colors.amber,
                              ),
                              const SectionHeader(title: "Selected PDF"),
                              SelectedFileCard(
                                file: provider.selectedFile!,
                                onChange: provider.isLoading
                                    ? null
                                    : () async {
                                        bool success = await provider.pickFile();
                                        if (success &&
                                            provider.selectedFile != null) {
                                          _loadPdfDocument(
                                              provider.selectedFile!.path);
                                        }
                                      },
                                badgeColor: Colors.amber,
                              ),
                              SectionHeader(
                                title: "Pages",
                                trailingText:
                                    "${provider.pages.length} pages • Drag handle to reorder",
                              ),
                              if (provider.isLoading) ...[
                                const Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 12),
                                  child: LinearProgressIndicator(
                                      color: Colors.amber),
                                ),
                                if (provider.statusMessage != null)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20),
                                    child: Text(
                                      provider.statusMessage!,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: theme.hintColor,
                                      ),
                                    ),
                                  ),
                              ],
                            ],
                          ),
                          itemCount: provider.pages.length,
                          onReorder: (oldIndex, newIndex) {
                            provider.reorderPages(oldIndex, newIndex);
                          },
                          itemBuilder: (context, index) {
                            final pageData = provider.pages[index];
                            final originalPageNum = pageData.originalIndex + 1;

                            return Card(
                              key: ValueKey("page_${pageData.originalIndex}"),
                              color: theme.cardColor,
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 4),
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                    color: theme.dividerColor.withAlpha(20)),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withAlpha(40),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          "${index + 1}",
                                          style: const TextStyle(
                                            color: Colors.amber,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      width: 48,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                            color: theme.dividerColor),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(5),
                                        child: _pdfDocument != null
                                            ? FutureBuilder<pdfx.PdfPageImage?>(
                                                future: _getPageThumbnail(
                                                    originalPageNum),
                                                builder: (context, snapshot) {
                                                  if (snapshot.hasData &&
                                                      snapshot.data != null) {
                                                    return Transform.rotate(
                                                      angle: pageData
                                                              .rotationDegrees *
                                                          math.pi /
                                                          180,
                                                      child: Image.memory(
                                                        snapshot.data!.bytes,
                                                        fit: BoxFit.contain,
                                                      ),
                                                    );
                                                  } else if (snapshot.connectionState ==
                                                          ConnectionState.done &&
                                                      snapshot.data == null) {
                                                    return const Icon(
                                                      Icons.description_outlined,
                                                      color: Colors.black26,
                                                    );
                                                  }
                                                  return const Center(
                                                      child:
                                                          CircularProgressIndicator(
                                                              strokeWidth: 2));
                                                },
                                              )
                                            : const Icon(
                                                Icons.description_outlined,
                                                color: Colors.black26),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Page ${index + 1}",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color:
                                                  theme.colorScheme.onSurface,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            "Original: Page $originalPageNum${pageData.rotationDegrees > 0 ? " • ${pageData.rotationDegrees}°" : ""}",
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: theme.hintColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                          Icons.rotate_left_rounded,
                                          color: Colors.blueAccent,
                                          size: 22),
                                      tooltip: "Rotate Left",
                                      onPressed: () => provider.rotatePage(
                                          index,
                                          counterClockwise: true),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                          Icons.rotate_right_rounded,
                                          color: Colors.blueAccent,
                                          size: 22),
                                      tooltip: "Rotate Right",
                                      onPressed: () =>
                                          provider.rotatePage(index),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          color: Colors.redAccent,
                                          size: 22),
                                      tooltip: "Delete Page",
                                      onPressed: provider.pages.length > 1
                                          ? () => provider.removePage(index)
                                          : null,
                                    ),
                                    const Icon(Icons.drag_handle_rounded,
                                        color: Colors.grey),
                                    const SizedBox(width: 4),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
              if (hasFile)
                BottomActionBar(
                  actionText: "Save Document",
                  isLoading: provider.isLoading,
                  color: Colors.amber,
                  onAction: () async {
                    final success = await provider.saveOrganizedPdf(context);
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
}
