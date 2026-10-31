import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf_toolkit/provider/pdf_to_excel_provider/pdf_to_excel_provider.dart';
import 'package:pdf_toolkit/utils/ad_helper.dart';
import 'package:pdf_toolkit/widgets/banner_ad_widget.dart';
import 'package:pdf_toolkit/widgets/tool_ui_components.dart';
import 'package:provider/provider.dart';

class PdfToExcelScreen extends StatefulWidget {
  const PdfToExcelScreen({super.key});

  @override
  State<PdfToExcelScreen> createState() => _PdfToExcelScreenState();
}

class _PdfToExcelScreenState extends State<PdfToExcelScreen> {
  String _selectedFormat = 'XLSX';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: const ToolAppBar(),
      body: Consumer<PdfToExcelProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(
                    0.0,
                  ), // Padding handled inside scroll view
                  child: provider.extractedGrid != null
                      ? _buildReviewPhase(context, theme, provider)
                      : _buildSelectionPhase(context, theme, isDark, provider),
                ),
              ),
              if (provider.extractedGrid == null &&
                  provider.selectedFile == null)
                const BannerAdWidget(placement: AdPlacement.tools),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSelectionPhase(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    PdfToExcelProvider provider,
  ) {
    final hasFile = provider.selectedFile != null;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ToolHeader(
            title: "PDF to Excel",
            subtitle: "Pull tables into a workbook you can edit.",
            icon: Icons.table_chart_rounded,
            color: Colors.green[700]!,
          ),

          const SectionHeader(title: "Selected document"),
          if (hasFile)
            SelectedFileCard(
              file: provider.selectedFile!,
              onChange: provider.isLoading ? null : () => provider.pickFile(),
              badgeColor: Colors.green[700]!,
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
              title: "Find tables",
              trailingText: "Recommended",
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.green[700]!.withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green[700]!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.center_focus_strong_rounded,
                            size: 18,
                            color: Colors.green[700],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Auto-detect",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.dividerColor.withAlpha(20),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.layers_rounded,
                            size: 18,
                            color: theme.hintColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "All pages selected",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
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
                    const Icon(Icons.check_circle_rounded, color: Colors.green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Full Document Scan",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            "App will analyze all pages for tabular data.",
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.hintColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.grid_on_rounded,
                      color: theme.hintColor.withAlpha(100),
                    ),
                  ],
                ),
              ),
            ),

            const SectionHeader(
              title: "Workbook output",
              trailingText: "Editable file",
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.dividerColor.withAlpha(20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Save as",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            "Keep tables in one workbook",
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.hintColor,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () =>
                                setState(() => _selectedFormat = 'XLSX'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: _selectedFormat == 'XLSX'
                                    ? Colors.green[700]!.withAlpha(20)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _selectedFormat == 'XLSX'
                                      ? Colors.green[700]!
                                      : theme.dividerColor,
                                ),
                              ),
                              child: Text(
                                "XLSX",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _selectedFormat == 'XLSX'
                                      ? Colors.green[700]
                                      : theme.hintColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () =>
                                setState(() => _selectedFormat = 'CSV'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: _selectedFormat == 'CSV'
                                    ? Colors.green[700]!.withAlpha(20)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _selectedFormat == 'CSV'
                                      ? Colors.green[700]!
                                      : theme.dividerColor,
                                ),
                              ),
                              child: Text(
                                "CSV",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _selectedFormat == 'CSV'
                                      ? Colors.green[700]
                                      : theme.hintColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (provider.isLoading) ...[
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: LinearProgressIndicator(
                  color: Colors.green[700],
                  value: provider.progress,
                ),
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

            const SizedBox(height: 100),
            BottomActionBar(
              actionText: "Prepare workbook",
              isLoading: provider.isLoading,
              color: Colors.green[700]!,
              onAction: () => provider.extractTableForReview(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewPhase(
    BuildContext context,
    ThemeData theme,
    PdfToExcelProvider provider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.preview_rounded, color: Colors.green[700]),
              const SizedBox(width: 8),
              Text(
                "Review Data Grid",
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
            "Table detection is based on text spacing. Tap cells to edit if columns merged incorrectly.",
            style: TextStyle(fontSize: 12, color: theme.hintColor),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              border: Border.all(color: theme.dividerColor),
              color: theme.cardColor,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowHeight: 0,
                  dataRowMaxHeight: double.infinity,
                  dataRowMinHeight: 40,
                  columns: List.generate(
                    provider.extractedGrid!.isNotEmpty
                        ? provider.extractedGrid![0].length
                        : 1,
                    (index) => const DataColumn(label: SizedBox.shrink()),
                  ),
                  rows: provider.extractedGrid!.asMap().entries.map((row) {
                    return DataRow(
                      cells: row.value.asMap().entries.map((col) {
                        return DataCell(
                          SizedBox(
                            width: 100, // Fixed width for editable cells
                            child: TextFormField(
                              initialValue: col.value,
                              maxLines: null,
                              style: const TextStyle(fontSize: 13),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              onChanged: (val) {
                                provider.updateGridCell(row.key, col.key, val);
                              },
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  }).toList(),
                ),
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
          BottomActionBar(
            actionText: "Save as $_selectedFormat",
            isLoading: provider.isLoading,
            color: Colors.green[700]!,
            onAction: () async {
              bool success = false;
              if (_selectedFormat == 'CSV') {
                success = await provider.saveAsCsv(context);
              } else {
                success = await provider.saveAsExcel(context);
              }
              if (success) {
                AdHelper.showInterstitialAd(() {});
              }
            },
          ),
      ],
    );
  }
}
