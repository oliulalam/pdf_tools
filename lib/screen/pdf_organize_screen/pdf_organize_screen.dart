import 'package:flutter/material.dart';
import 'package:pdf_toolkit/provider/pdf_organize_provider/pdf_organize_provider.dart';
import 'package:pdf_toolkit/utils/ad_helper.dart';
import 'package:pdf_toolkit/widgets/banner_ad_widget.dart';
import 'package:pdf_toolkit/widgets/tool_ui_components.dart';
import 'package:provider/provider.dart';

class PdfOrganizeScreen extends StatefulWidget {
  const PdfOrganizeScreen({super.key});

  @override
  State<PdfOrganizeScreen> createState() => _PdfOrganizeScreenState();
}

class _PdfOrganizeScreenState extends State<PdfOrganizeScreen> {
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
                    if (hasFile)
                      SelectedFileCard(
                        file: provider.selectedFile!,
                        onChange: provider.isLoading ? null : () => provider.pickFile(),
                        badgeColor: Colors.amber,
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
                      const SectionHeader(
                        title: "Pages",
                        trailingText: "Drag to reorder",
                      ),
                      if (provider.isLoading && provider.pages.isEmpty)
                        const Expanded(child: Center(child: CircularProgressIndicator()))
                      else
                        Expanded(
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              canvasColor: Colors.transparent,
                            ),
                            child: ReorderableListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              itemCount: provider.pages.length,
                              onReorder: (oldIndex, newIndex) {
                                provider.reorderPages(oldIndex, newIndex);
                              },
                              itemBuilder: (context, index) {
                                final pageData = provider.pages[index];
                                return Card(
                                  key: ValueKey("page_${pageData.originalIndex}"),
                                  color: theme.cardColor,
                                  margin: const EdgeInsets.only(bottom: 8),
                                  elevation: 1,
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.amber.withAlpha(50),
                                      child: Text(
                                        "${pageData.originalIndex + 1}",
                                        style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    title: Text("Page ${pageData.originalIndex + 1}"),
                                    subtitle: Text(
                                      "Rotation: ${pageData.rotationDegrees}°",
                                      style: TextStyle(color: theme.hintColor, fontSize: 12),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.rotate_left_rounded, color: Colors.blueAccent),
                                          onPressed: () => provider.rotatePage(index, counterClockwise: true),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.rotate_right_rounded, color: Colors.blueAccent),
                                          onPressed: () => provider.rotatePage(index),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                          onPressed: provider.pages.length > 1 
                                              ? () => provider.removePage(index) 
                                              : null,
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(Icons.drag_handle_rounded, color: Colors.grey),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      if (provider.isLoading && provider.pages.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          child: LinearProgressIndicator(color: Colors.amber),
                        ),
                        if (provider.statusMessage != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
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
                      const SizedBox(height: 100),
                    ]
                  ],
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
