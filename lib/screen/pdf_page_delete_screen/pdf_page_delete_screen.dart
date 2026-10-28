import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf_toolkit/utils/ad_helper.dart';
import 'package:pdf_toolkit/widgets/banner_ad_widget.dart';
import 'package:pdf_toolkit/widgets/tool_ui_components.dart';
import 'package:provider/provider.dart';
import '../../provider/pdf_page_delete_provider/pdf_page_delete_provider.dart';

class PdfPageDeleteScreen extends StatefulWidget {
  const PdfPageDeleteScreen({super.key});

  @override
  State<PdfPageDeleteScreen> createState() => _PdfPageDeleteScreenState();
}

class _PdfPageDeleteScreenState extends State<PdfPageDeleteScreen> {
  final Set<int> _selectedPages = {};

  void _togglePage(int page) {
    setState(() {
      if (_selectedPages.contains(page)) {
        _selectedPages.remove(page);
      } else {
        _selectedPages.add(page);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedPages.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: const ToolAppBar(),
      body: Consumer<PdfPageDeleteProvider>(
        builder: (context, provider, child) {
          final hasFile = provider.selectedFile != null;
          final remaining = hasFile
              ? provider.totalPages - _selectedPages.length
              : 0;

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ToolHeader(
                        title: "Remove pages",
                        subtitle: "Choose the pages to leave out of a new PDF.",
                        icon: Icons.delete_outline_rounded,
                        color: Colors.pinkAccent,
                      ),

                      SectionHeader(
                        title: "Selected PDF",
                        trailingText: hasFile ? "Example preview" : null,
                      ),

                      if (hasFile)
                        SelectedFileCard(
                          file: provider.selectedFile!,
                          onChange: provider.isLoading
                              ? null
                              : () {
                                  _clearSelection();
                                  provider.pickFile();
                                },
                          badgeColor: Colors.pinkAccent,
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          child: InkWell(
                            onTap: provider.isLoading
                                ? null
                                : () => provider.pickFile(),
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

                      if (hasFile) ...[
                        SectionHeader(
                          title: "Tap pages to remove",
                          trailingText: "${provider.totalPages} pages",
                        ),

                        Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          padding: const EdgeInsets.all(16),
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
                                  Icon(
                                    Icons.refresh_rounded,
                                    size: 14,
                                    color: theme.hintColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Page order - tap a thumbnail to toggle",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.hintColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 4,
                                      childAspectRatio: 0.5,
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 24,
                                    ),
                                itemCount: provider.totalPages,
                                itemBuilder: (context, index) {
                                  final pageNum = index + 1;
                                  final isSelected = _selectedPages.contains(
                                    pageNum,
                                  );
                                  return GestureDetector(
                                    onTap: () => _togglePage(pageNum),
                                    child: Column(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: isSelected
                                                    ? Colors.pinkAccent
                                                    : theme.dividerColor,
                                                width: isSelected ? 2 : 1,
                                              ),
                                              boxShadow: [
                                                if (isSelected)
                                                  BoxShadow(
                                                    color: Colors.pinkAccent
                                                        .withAlpha(50),
                                                    blurRadius: 8,
                                                  ),
                                              ],
                                            ),
                                            child: Stack(
                                              children: [
                                                if (isSelected)
                                                  const Positioned(
                                                    top: 4,
                                                    left: 4,
                                                    child: Icon(
                                                      Icons
                                                          .check_circle_rounded,
                                                      color: Colors.pinkAccent,
                                                      size: 16,
                                                    ),
                                                  ),
                                                Align(
                                                  alignment:
                                                      Alignment.bottomCenter,
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          bottom: 8,
                                                        ),
                                                    child: Text(
                                                      "$pageNum",
                                                      style: const TextStyle(
                                                        color: Colors.black54,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          isSelected
                                              ? "Remove"
                                              : "Page $pageNum",
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            color: isSelected
                                                ? Colors.pinkAccent
                                                : theme.hintColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Pages ${_selectedPages.join(', ')} selected",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                      ),
                                      Text(
                                        "$remaining of ${provider.totalPages} pages will remain",
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: theme.hintColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  TextButton(
                                    onPressed: _clearSelection,
                                    child: const Text(
                                      "Clear selection",
                                      style: TextStyle(
                                        color: Colors.pinkAccent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.withAlpha(20),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.orange.withAlpha(50),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.orange,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Check your selection before continuing",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: Colors.orange,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Removed pages won't be included in the new copy. Your original PDF stays unchanged.",
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
                        ),

                        if (provider.isLoading) ...[
                          const SizedBox(height: 24),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            child: LinearProgressIndicator(
                              color: Colors.pinkAccent,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            provider.statusMessage ?? "Processing...",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.hintColor,
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
              if (hasFile)
                BottomActionBar(
                  actionText: "Remove ${_selectedPages.length} pages",
                  isLoading: provider.isLoading,
                  color: Colors.pinkAccent,
                  onAction: _selectedPages.isEmpty
                      ? null
                      : () async {
                          final success = await provider.deletePagesAndSave(
                            context,
                            _selectedPages.toList(),
                          );
                          if (success) {
                            AdHelper.showInterstitialAd(() {});
                          }
                        },
                ),
              if (!hasFile) const BannerAdWidget(),
            ],
          );
        },
      ),
    );
  }
}
