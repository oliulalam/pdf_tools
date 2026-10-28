import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf_toolkit/provider/pdf_to_word_provider/pdf_to_word_provider.dart';
import 'package:pdf_toolkit/utils/ad_helper.dart';
import 'package:pdf_toolkit/widgets/banner_ad_widget.dart';
import 'package:pdf_toolkit/widgets/tool_ui_components.dart';
import 'package:provider/provider.dart';

class PdfToWordScreen extends StatefulWidget {
  const PdfToWordScreen({super.key});

  @override
  State<PdfToWordScreen> createState() => _PdfToWordScreenState();
}

class _PdfToWordScreenState extends State<PdfToWordScreen> {
  final TextEditingController _reviewController = TextEditingController();
  bool _useOcr =
      true; // Always true for now as our implementation relies on ML Kit

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Consumer<PdfToWordProvider>(
      builder: (context, provider, child) {
        // Auto-fill review controller when extraction is done
        if (provider.extractedText != null && _reviewController.text.isEmpty) {
          _reviewController.text = provider.extractedText!;
        }

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: const ToolAppBar(),
          body: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(0),
                  child: provider.extractedText != null
                      ? _buildReviewPhase(context, theme, provider)
                      : _buildSelectionPhase(context, theme, isDark, provider),
                ),
              ),
              if (provider.extractedText == null &&
                  provider.selectedFile == null)
                const BannerAdWidget(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSelectionPhase(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    PdfToWordProvider provider,
  ) {
    final hasFile = provider.selectedFile != null;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ToolHeader(
            title: "PDF to Word",
            subtitle: "Choose how your document should become editable.",
            icon: Icons.description_rounded,
            color: Colors.blue[700]!,
          ),

          SectionHeader(
            title: "Your PDF",
            trailingText: hasFile ? "Selected file" : null,
          ),

          if (hasFile)
            SelectedFileCard(
              file: provider.selectedFile!,
              onChange: provider.isLoading ? null : () => provider.pickFile(),
              badgeColor: Colors.blue[700]!,
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: InkWell(
                onTap: provider.isLoading ? null : () => provider.pickFile(),
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
            const SectionHeader(
              title: "Word document",
              trailingText: "Editable .docx",
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.dividerColor.withAlpha(20)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[700]!.withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.description_outlined,
                        color: Colors.blue[700],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${provider.selectedFile!.path.split(Platform.pathSeparator).last.replaceAll('.pdf', '')}.docx",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Microsoft Word document",
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.hintColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue[700]!.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "DOCX",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          color: Colors.blue[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SectionHeader(title: "Choose a conversion style"),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.dividerColor.withAlpha(20),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Icon(
                                Icons.dashboard_customize_outlined,
                                size: 20,
                                color: theme.hintColor.withAlpha(100),
                              ),
                              Icon(
                                Icons.radio_button_unchecked_rounded,
                                size: 18,
                                color: theme.hintColor.withAlpha(100),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Keep original layout",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: theme.hintColor.withAlpha(100),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Not supported offline",
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.redAccent.withAlpha(150),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[700]!.withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue[700]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Icon(
                                Icons.edit_note_rounded,
                                size: 20,
                                color: Colors.blue[700],
                              ),
                              Icon(
                                Icons.check_circle_rounded,
                                size: 18,
                                color: Colors.blue[700],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Easier editing",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Prioritizes clean, flowing text.",
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.hintColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SectionHeader(
              title: "Scanned pages",
              trailingText: "AI Detection",
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.dividerColor.withAlpha(20)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.document_scanner_rounded,
                        color: Colors.blue[700],
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Recognize text (OCR)",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Make text selectable and editable.",
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.hintColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _useOcr,
                      activeColor: Colors.blue[700],
                      onChanged: (val) {
                        // Fixed to true since our backend uses OCR
                      },
                    ),
                  ],
                ),
              ),
            ),

            if (provider.isLoading) ...[
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: LinearProgressIndicator(
                  color: Colors.blue[700],
                  value: provider.progress,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                provider.statusMessage ?? "Processing...",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: theme.hintColor),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => provider.cancel(),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 40),
            if (!provider.isLoading)
              BottomActionBar(
                actionText: "Extract Text",
                isLoading: provider.isLoading,
                color: Colors.blue[700]!,
                onAction: () async {
                  await provider.extractTextForReview();
                },
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewPhase(
    BuildContext context,
    ThemeData theme,
    PdfToWordProvider provider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.edit_document, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Text(
                "Review & Edit Text",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            "Please review and fix any OCR mistakes before exporting.",
            style: TextStyle(fontSize: 12, color: theme.hintColor),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              border: Border.all(color: theme.dividerColor),
              borderRadius: BorderRadius.circular(12),
              color: theme.cardColor,
            ),
            child: TextField(
              controller: _reviewController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
              ),
            ),
          ),
        ),
        if (provider.isLoading)
          const Padding(
            padding: EdgeInsets.all(24.0),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      provider.reset();
                      _reviewController.clear();
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.blue[700]!),
                      foregroundColor: Colors.blue[700],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("Start Over"),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () async {
                      final success = await provider.saveWordDocument(
                        context,
                        _reviewController.text,
                      );
                      if (success) {
                        AdHelper.showInterstitialAd(() {});
                      }
                    },
                    icon: const Icon(Icons.save_alt),
                    label: const Text("Save as Word"),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blue[700],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
