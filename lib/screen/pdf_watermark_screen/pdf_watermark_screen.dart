import 'package:flutter/material.dart';
import 'package:pdf_toolkit/provider/pdf_watermark_provider/pdf_watermark_provider.dart';
import 'package:pdf_toolkit/utils/ad_helper.dart';
import 'package:pdf_toolkit/widgets/banner_ad_widget.dart';
import 'package:pdf_toolkit/widgets/tool_ui_components.dart';
import 'package:provider/provider.dart';

class PdfWatermarkScreen extends StatefulWidget {
  const PdfWatermarkScreen({super.key});

  @override
  State<PdfWatermarkScreen> createState() => _PdfWatermarkScreenState();
}

class _PdfWatermarkScreenState extends State<PdfWatermarkScreen> {
  final TextEditingController _textController = TextEditingController(text: "CONFIDENTIAL");

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<PdfWatermarkProvider>(
      builder: (context, provider, child) {
        final hasFile = provider.selectedFile != null;

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: const ToolAppBar(),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ToolHeader(
                        title: "Watermark & Page Numbers",
                        subtitle: "Add text watermark or page numbers.",
                        icon: Icons.branding_watermark_rounded,
                        color: Colors.blueGrey,
                      ),
                      
                      const SectionHeader(title: "Selected PDF"),
                      if (hasFile)
                        SelectedFileCard(
                          file: provider.selectedFile!,
                          onChange: provider.isLoading ? null : () => provider.pickFile(),
                          badgeColor: Colors.blueGrey,
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
                                border: Border.all(color: theme.dividerColor),
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
                        const SectionHeader(title: "Options"),
                        
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: theme.dividerColor.withAlpha(20)),
                          ),
                          child: Column(
                            children: [
                              SwitchListTile(
                                title: const Text("Add Watermark", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                subtitle: Text("Diagonal text in the center", style: TextStyle(fontSize: 12, color: theme.hintColor)),
                                value: provider.addWatermark,
                                activeColor: Colors.blueGrey,
                                onChanged: (val) => provider.setWatermark(val),
                              ),
                              if (provider.addWatermark)
                                Padding(
                                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                                  child: TextField(
                                    controller: _textController,
                                    decoration: const InputDecoration(
                                      labelText: "Watermark Text",
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    onChanged: (val) => provider.setWatermarkText(val),
                                  ),
                                ),
                              const Divider(),
                              SwitchListTile(
                                title: const Text("Add Page Numbers", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                subtitle: Text("Bottom center of each page", style: TextStyle(fontSize: 12, color: theme.hintColor)),
                                value: provider.addPageNumbers,
                                activeColor: Colors.blueGrey,
                                onChanged: (val) => provider.setPageNumbers(val),
                              ),
                            ],
                          ),
                        ),

                        if (provider.isLoading) ...[
                          const SizedBox(height: 24),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            child: LinearProgressIndicator(color: Colors.blueGrey),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              provider.statusMessage ?? "Processing...",
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: theme.hintColor),
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
              if (hasFile)
                BottomActionBar(
                  actionText: "Save Document",
                  isLoading: provider.isLoading,
                  color: Colors.blueGrey,
                  onAction: () async {
                    if (!provider.addWatermark && !provider.addPageNumbers) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Select at least one option to apply")),
                      );
                      return;
                    }
                    final success = await provider.processAndSave(context);
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
