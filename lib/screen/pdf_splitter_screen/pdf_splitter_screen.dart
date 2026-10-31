import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdf_toolkit/provider/pdf_split_provider/pdf_split_provider.dart';
import 'package:pdf_toolkit/utils/ad_helper.dart';
import 'package:pdf_toolkit/widgets/banner_ad_widget.dart';
import 'package:pdf_toolkit/widgets/tool_ui_components.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';

class PdfSplitterScreen extends StatefulWidget {
  const PdfSplitterScreen({super.key});

  @override
  State<PdfSplitterScreen> createState() => _PdfSplitterScreenState();
}

class _PdfSplitterScreenState extends State<PdfSplitterScreen> {
  bool _splitIntoParts = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PdfSplitProvider>().reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: const ToolAppBar(),
      body: Consumer<PdfSplitProvider>(
        builder: (context, provider, child) {
          final hasFile = provider.pdfPath != null;

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ToolHeader(
                        title: "Split document",
                        subtitle:
                            "Keep the pages you need. Choose how they're separated.",
                        icon: Icons.content_cut_rounded,
                        color: Colors.redAccent,
                      ),

                      const SectionHeader(title: "Choose a split style"),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _splitIntoParts = false),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: !_splitIntoParts ? theme.cardColor : theme.scaffoldBackgroundColor,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: !_splitIntoParts ? Colors.redAccent : theme.dividerColor.withAlpha(20),
                                      width: !_splitIntoParts ? 2 : 1,
                                    ),
                                    boxShadow: [
                                      if (!_splitIntoParts)
                                        BoxShadow(
                                          color: Colors.redAccent.withAlpha(20),
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
                                          color: !_splitIntoParts ? Colors.redAccent.withAlpha(20) : theme.hintColor.withAlpha(20),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Icons.content_cut_rounded,
                                          color: !_splitIntoParts ? Colors.redAccent : theme.hintColor,
                                          size: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Extract pages",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: !_splitIntoParts ? theme.colorScheme.onSurface : theme.hintColor,
                                              ),
                                            ),
                                            Text(
                                              "One new PDF",
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: theme.hintColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        !_splitIntoParts ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                        color: !_splitIntoParts ? Colors.redAccent : theme.hintColor.withAlpha(100),
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _splitIntoParts = true),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: _splitIntoParts ? theme.cardColor : theme.scaffoldBackgroundColor,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: _splitIntoParts ? Colors.redAccent : theme.dividerColor.withAlpha(20),
                                      width: _splitIntoParts ? 2 : 1,
                                    ),
                                    boxShadow: [
                                      if (_splitIntoParts)
                                        BoxShadow(
                                          color: Colors.redAccent.withAlpha(20),
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
                                          color: _splitIntoParts ? Colors.redAccent.withAlpha(20) : theme.hintColor.withAlpha(20),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Icons.file_copy_rounded,
                                          color: _splitIntoParts ? Colors.redAccent : theme.hintColor,
                                          size: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Split into parts",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: _splitIntoParts ? theme.colorScheme.onSurface : theme.hintColor,
                                              ),
                                            ),
                                            Text(
                                              "Several new PDFs",
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: theme.hintColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        _splitIntoParts ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                        color: _splitIntoParts ? Colors.redAccent : theme.hintColor.withAlpha(100),
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SectionHeader(title: "Source document"),
                      if (hasFile)
                        SelectedFileCard(
                          file: File(provider.pdfPath!),
                          overrideName: provider.pdfName,
                          onChange: provider.isLoading
                              ? null
                              : () => provider.pickPdf(context),
                          badgeColor: Colors.redAccent,
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
                                : () => provider.pickPdf(context),
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
                          title: "Pages to include",
                          trailingText: "${provider.totalPages} total pages",
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: theme.dividerColor.withAlpha(20),
                              ),
                            ),
                            child: TextField(
                              controller: provider.rangeController,
                              enabled: !provider.isLoading,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                              ),
                              decoration: InputDecoration(
                                hintText: 'e.g. 1-3, 5, 7',
                                hintStyle: TextStyle(color: theme.hintColor),
                                border: InputBorder.none,
                                suffixIcon: Icon(
                                  Icons.edit_rounded,
                                  color: theme.hintColor,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            "Enter page numbers separated by commas or dashes.",
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.hintColor,
                            ),
                          ),
                        ),
                      ],

                      if (provider.generatedFiles.isNotEmpty) ...[
                        SectionHeader(
                          title: provider.generatedFiles.length > 1 ? "Your new PDFs" : "Your new PDF",
                          trailingText: "${provider.generatedFiles.length} file${provider.generatedFiles.length > 1 ? 's' : ''}",
                        ),
                        SelectedFileCard(
                          file: File(provider.generatedFiles.first),
                          badgeText: "${provider.generatedFiles.length} PDF${provider.generatedFiles.length > 1 ? 's' : ''}",
                          badgeColor: Colors.redAccent,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.auto_awesome_rounded,
                                color: Colors.red[300],
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "A copy is made from the selected pages. Your source PDF is never changed.",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.hintColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      if (provider.isLoading) ...[
                        const SizedBox(height: 24),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: LinearProgressIndicator(
                            color: Colors.redAccent,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            provider.statusMessage,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.hintColor,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
              if (hasFile && provider.generatedFiles.isEmpty)
                BottomActionBar(
                  actionText: "Create selected PDF",
                  isLoading: provider.isLoading,
                  color: Colors.redAccent,
                  onAction: () async {
                    final success = await provider.splitSelectedPdf(context, splitIntoParts: _splitIntoParts);
                    if (success) {
                      // NO AD HERE - wait for export
                    }
                  },
                ),
              if (provider.generatedFiles.isNotEmpty)
                BottomActionBar(
                  actionText: "Export Document",
                  isLoading: provider.isLoading,
                  color: Colors.redAccent,
                  onAction: () async {
                    final success = await provider.saveFilesSmart(context);
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
}
