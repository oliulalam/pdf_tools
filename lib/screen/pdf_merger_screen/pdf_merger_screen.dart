import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf_toolkit/provider/pdf_merger_provider/pdf_merger_provider.dart';
import 'package:pdf_toolkit/utils/ad_helper.dart';
import 'package:pdf_toolkit/widgets/banner_ad_widget.dart';
import 'package:pdf_toolkit/widgets/tool_ui_components.dart';
import 'package:provider/provider.dart';

class PdfMergerScreen extends StatefulWidget {
  const PdfMergerScreen({super.key});

  @override
  State<PdfMergerScreen> createState() => _PdfMergerScreenState();
}

class _PdfMergerScreenState extends State<PdfMergerScreen> {
  final TextEditingController _fileNameController = TextEditingController();

  @override
  void dispose() {
    _fileNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: const ToolAppBar(),
      body: Consumer<PdfMergerProvider>(
        builder: (context, provider, child) {
          final hasFiles = provider.hasFile;

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ToolHeader(
                        title: "Merge Documents",
                        subtitle:
                            "Put your PDFs together in the order you choose.",
                        icon: Icons.layers_rounded,
                        color: Colors.teal,
                      ),

                      SectionHeader(
                        title: "Documents in merge",
                        trailingText: "${provider.fileCount} selected",
                      ),

                      if (hasFiles)
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
                            child: ReorderableListView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              itemCount: provider.fileCount,
                              onReorder: (oldIndex, newIndex) {
                                if (newIndex > oldIndex) newIndex -= 1;
                                provider.reorder(oldIndex, newIndex);
                              },
                              itemBuilder: (context, index) {
                                final file = provider.selectedFiles[index];
                                final name = file.path
                                    .split(Platform.pathSeparator)
                                    .last;
                                final sizeKb = provider.getFileSize(file.path);
                                final sizeMb = sizeKb / 1024;
                                final sizeStr = sizeMb > 1
                                    ? "${sizeMb.toStringAsFixed(1)} MB"
                                    : "${sizeKb.toStringAsFixed(1)} KB";

                                return Container(
                                  key: ValueKey(file.path),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: index < provider.fileCount - 1
                                            ? theme.dividerColor.withAlpha(20)
                                            : Colors.transparent,
                                      ),
                                    ),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 4,
                                    ),
                                    leading: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.teal.withAlpha(30),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            "${index + 1}",
                                            style: const TextStyle(
                                              color: Colors.teal,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Icon(
                                          Icons.drag_indicator_rounded,
                                          color: theme.hintColor.withAlpha(100),
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                    title: Row(
                                      children: [
                                        Icon(
                                          Icons.description_outlined,
                                          color: Colors.teal,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color:
                                                  theme.colorScheme.onSurface,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(
                                        left: 24,
                                        top: 2,
                                      ),
                                      child: Text(
                                        sizeStr,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: theme.hintColor,
                                        ),
                                      ),
                                    ),
                                    trailing: IconButton(
                                      icon: Icon(
                                        Icons.close_rounded,
                                        color: theme.hintColor,
                                        size: 18,
                                      ),
                                      onPressed: () =>
                                          provider.removeFile(index),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          child: Text(
                            "No documents selected.",
                            style: TextStyle(color: theme.hintColor),
                          ),
                        ),

                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        child: OutlinedButton.icon(
                          onPressed: provider.isMerging
                              ? null
                              : provider.pickFiles,
                          icon: const Icon(Icons.add_rounded),
                          label: const Expanded(child: Text("Add another PDF")),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                            side: BorderSide(
                              color: theme.dividerColor,
                              style: BorderStyle.solid,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            foregroundColor: theme.colorScheme.onSurface,
                            alignment: Alignment.centerLeft,
                          ),
                        ),
                      ),

                      if (provider.fileCount >= 2) ...[
                        const SectionHeader(
                          title: "Merged file",
                          trailingText: "Ready to create",
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: theme.dividerColor.withAlpha(20),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: theme.scaffoldBackgroundColor,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.file_copy_outlined,
                                      color: theme.colorScheme.onSurface,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Your combined PDF",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                        ),
                                        Text(
                                          "Documents will follow the order above",
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: theme.hintColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              Text(
                                "Output file name",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: theme.hintColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.scaffoldBackgroundColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: theme.dividerColor.withAlpha(50),
                                  ),
                                ),
                                child: TextField(
                                  controller: _fileNameController,
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: "Combined_Document",
                                    hintStyle: TextStyle(
                                      color: theme.hintColor.withAlpha(100),
                                    ),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      if (provider.isMerging) ...[
                        const SizedBox(height: 24),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: LinearProgressIndicator(color: Colors.teal),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          provider.statusMessage ?? "Merging...",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.hintColor,
                          ),
                        ),
                      ],
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
              if (provider.fileCount >= 2)
                BottomActionBar(
                  actionText: "Merge ${provider.fileCount} PDFs",
                  isLoading: provider.isMerging,
                  color: Colors.teal,
                  onAction: () async {
                    final success = await provider.mergeAndSave(
                      context,
                      customFileName: _fileNameController.text,
                    );
                    if (success) {
                      AdHelper.showInterstitialAd(() {});
                    }
                  },
                ),
              if (provider.fileCount < 2) const BannerAdWidget(),
            ],
          );
        },
      ),
    );
  }
}
