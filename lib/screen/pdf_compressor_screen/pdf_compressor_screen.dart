import 'package:flutter/material.dart';
import 'package:pdf_toolkit/utils/ad_helper.dart';
import 'package:pdf_toolkit/widgets/banner_ad_widget.dart';
import 'package:pdf_toolkit/widgets/tool_ui_components.dart';
import 'package:provider/provider.dart';
import '../../provider/pdf_compressor_provider/pdf_compressor_provider.dart';

class PdfCompressorScreen extends StatelessWidget {
  const PdfCompressorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: const ToolAppBar(),
      body: Consumer<PdfCompressorProvider>(
        builder: (context, provider, child) {
          final hasFile = provider.selectedFile != null;
          final double currentSizeMb = _calculateCurrentSize(provider);

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ToolHeader(
                        title: "Compress PDF",
                        subtitle:
                            "Make your PDF smaller, without the guesswork.",
                        icon: Icons.compress_rounded,
                        color: Colors.deepPurpleAccent,
                      ),

                      const SectionHeader(title: "Selected document"),
                      if (hasFile)
                        SelectedFileCard(
                          file: provider.selectedFile!,
                          onChange: provider.isLoading
                              ? null
                              : () => provider.pickFile(),
                          badgeColor: Colors.deepPurpleAccent,
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
                        const SectionHeader(
                          title: "Choose a compression level",
                          trailingText: "Compare estimates",
                        ),
                        _buildCompressionOption(
                          context: context,
                          theme: theme,
                          isDark: isDark,
                          title: "Smaller file",
                          subtitle: "Keep details crisp",
                          icon: Icons.auto_awesome_rounded,
                          qualityValue: 0.8,
                          currentQuality: provider.quality,
                          originalSizeMb: currentSizeMb,
                          estimatedReduction:
                              0.27, // Mock estimation percentage
                          onSelect: () => provider.setQuality(0.8),
                        ),
                        _buildCompressionOption(
                          context: context,
                          theme: theme,
                          isDark: isDark,
                          title: "Recommended",
                          subtitle: "Great balance",
                          icon: Icons.speed_rounded,
                          qualityValue: 0.5,
                          currentQuality: provider.quality,
                          originalSizeMb: currentSizeMb,
                          estimatedReduction: 0.49,
                          onSelect: () => provider.setQuality(0.5),
                          isRecommended: true,
                        ),
                        _buildCompressionOption(
                          context: context,
                          theme: theme,
                          isDark: isDark,
                          title: "Smallest file",
                          subtitle: "More compression",
                          icon: Icons.bolt_rounded,
                          qualityValue: 0.2,
                          currentQuality: provider.quality,
                          originalSizeMb: currentSizeMb,
                          estimatedReduction: 0.68,
                          onSelect: () => provider.setQuality(0.2),
                        ),

                        const SectionHeader(title: "Your estimated result"),
                        _buildEstimationCard(
                          theme,
                          isDark,
                          provider.quality,
                          currentSizeMb,
                        ),

                        if (provider.isLoading) ...[
                          const SizedBox(height: 24),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: LinearProgressIndicator(
                              color: Colors.deepPurpleAccent,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            provider.statusMessage ?? "Compressing...",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.hintColor,
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 40), // Bottom padding
                    ],
                  ),
                ),
              ),
              if (hasFile)
                BottomActionBar(
                  actionText: "Continue",
                  isLoading: provider.isLoading,
                  color: Colors.deepPurpleAccent,
                  onAction: () async {
                    final success = await provider.compressAndSave(context);
                    if (success) {
                      AdHelper.showInterstitialAd(() {});
                    }
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  double _calculateCurrentSize(PdfCompressorProvider provider) {
    if (provider.selectedFile == null) return 0.0;
    try {
      if (provider.selectedFile!.existsSync()) {
        return provider.selectedFile!.lengthSync() / (1024 * 1024);
      }
    } catch (_) {}
    return 0.0;
  }

  Widget _buildCompressionOption({
    required BuildContext context,
    required ThemeData theme,
    required bool isDark,
    required String title,
    required String subtitle,
    required IconData icon,
    required double qualityValue,
    required double currentQuality,
    required double originalSizeMb,
    required double estimatedReduction,
    required VoidCallback onSelect,
    bool isRecommended = false,
  }) {
    final isSelected = (currentQuality - qualityValue).abs() < 0.01;
    final estimatedSize = originalSizeMb * (1 - estimatedReduction);

    return GestureDetector(
      onTap: onSelect,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Colors.deepPurpleAccent
                : theme.dividerColor.withAlpha(20),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: Colors.deepPurpleAccent.withAlpha(20),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.deepPurpleAccent : theme.hintColor,
              size: 28,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      if (isRecommended) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.deepPurpleAccent.withAlpha(40),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            "BEST BALANCE",
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurpleAccent,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: theme.hintColor),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "${estimatedSize.toStringAsFixed(1)} MB",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  "about ${(estimatedReduction * 100).toInt()}% smaller",
                  style: TextStyle(fontSize: 10, color: theme.hintColor),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Icon(
              isSelected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isSelected
                  ? Colors.deepPurpleAccent
                  : theme.hintColor.withAlpha(100),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEstimationCard(
    ThemeData theme,
    bool isDark,
    double quality,
    double originalSizeMb,
  ) {
    double estimatedReduction = 0.49;
    if (quality >= 0.8) estimatedReduction = 0.27;
    if (quality <= 0.2) estimatedReduction = 0.68;

    final estimatedSize = originalSizeMb * (1 - estimatedReduction);

    return Container(
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
              Text(
                "Estimated output size",
                style: TextStyle(fontSize: 12, color: theme.hintColor),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.deepPurpleAccent.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "${(estimatedReduction * 100).toInt()}% smaller",
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurpleAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "${estimatedSize.toStringAsFixed(1)} MB",
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 1 - estimatedReduction,
              backgroundColor: theme.dividerColor.withAlpha(30),
              color: Colors.deepPurpleAccent,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Original ${originalSizeMb.toStringAsFixed(1)} MB",
                style: TextStyle(fontSize: 11, color: theme.hintColor),
              ),
              Text(
                "Estimate may vary",
                style: TextStyle(fontSize: 11, color: theme.hintColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
