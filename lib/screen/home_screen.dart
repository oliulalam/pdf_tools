import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdf_toolkit/app.dart';

// Providers
import 'package:fluttertoast/fluttertoast.dart';
import 'package:pdf_toolkit/provider/file_history_provider.dart';
import 'package:pdf_toolkit/provider/image_to_pdf_provider/images_to_pdf_provider.dart';
import 'package:pdf_toolkit/provider/pdf_compressor_provider/pdf_compressor_provider.dart';
import 'package:pdf_toolkit/provider/pdf_merger_provider/pdf_merger_provider.dart';
import 'package:pdf_toolkit/provider/pdf_page_delete_provider/pdf_page_delete_provider.dart';
import 'package:pdf_toolkit/provider/pdf_split_provider/pdf_split_provider.dart';
import 'package:pdf_toolkit/provider/pdf_to_image_provider/pdf_to_image_provider.dart';
import 'package:pdf_toolkit/provider/pdf_to_word_provider/pdf_to_word_provider.dart';
import 'package:pdf_toolkit/provider/pdf_to_excel_provider/pdf_to_excel_provider.dart';
import 'package:pdf_toolkit/provider/pdf_presenter_provider/pdf_presenter_provider.dart';

// Screens
import 'package:pdf_toolkit/screen/image_to_pdf_screen/selected_images_screen.dart';
import 'package:pdf_toolkit/screen/pdf_compressor_screen/pdf_compressor_screen.dart';
import 'package:pdf_toolkit/screen/pdf_merger_screen/pdf_merger_screen.dart';
import 'package:pdf_toolkit/screen/pdf_page_delete_screen/pdf_page_delete_screen.dart';
import 'package:pdf_toolkit/screen/pdf_splitter_screen/pdf_splitter_screen.dart';
import 'package:pdf_toolkit/screen/pdf_to_image_screen/pdf_to_image_home_screen.dart';
import 'package:pdf_toolkit/screen/pdf_to_word_screen/pdf_to_word_screen.dart';
import 'package:pdf_toolkit/screen/pdf_to_excel_screen/pdf_to_excel_screen.dart';
import 'package:pdf_toolkit/screen/pdf_presenter_screen/pdf_presenter_screen.dart';
import 'package:pdf_toolkit/screen/pdf_security_screen/pdf_security_screen.dart';
import 'package:pdf_toolkit/screen/pdf_organize_screen/pdf_organize_screen.dart';
import 'package:pdf_toolkit/screen/pdf_watermark_screen/pdf_watermark_screen.dart';
import 'package:pdf_toolkit/screen/privacy_policy_screen.dart';
import 'package:pdf_toolkit/screen/settings_screen.dart';
import 'package:pdf_toolkit/provider/pdf_security_provider/pdf_security_provider.dart';
import 'package:pdf_toolkit/provider/pdf_organize_provider/pdf_organize_provider.dart';
import 'package:pdf_toolkit/provider/pdf_watermark_provider/pdf_watermark_provider.dart';
import 'package:pdf_toolkit/provider/pdf_scanner_provider/pdf_scanner_provider.dart';

// Utils
import 'package:pdf_toolkit/utils/ad_helper.dart';
import 'package:pdf_toolkit/widgets/banner_ad_widget.dart';

class PdfTool {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  PdfTool({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    AdHelper.loadInterstitialAd();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PdfToolKitApp.checkAndOpenPendingSharedFile(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Apply strict status bar coloring to match the design
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: theme.brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarColor: theme.scaffoldBackgroundColor,
        systemNavigationBarIconBrightness: theme.brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: [const _HomeTab(), const _RecentTab(), const _ToolsTab()],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(
                theme.brightness == Brightness.dark ? 80 : 15,
              ),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: theme.scaffoldBackgroundColor,
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          selectedItemColor: theme.colorScheme.primary,
          unselectedItemColor: theme.hintColor,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.access_time_rounded),
              activeIcon: Icon(Icons.access_time_filled_rounded),
              label: 'Recent',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_rounded),
              activeIcon: Icon(Icons.grid_view_rounded),
              label: 'Tools',
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------
// HOME TAB
// --------------------------------------------------------------------------

class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  late final List<PdfTool> _allTools;

  @override
  void initState() {
    super.initState();
    _allTools = [
      PdfTool(
        title: "image_to_pdf".tr(),
        subtitle: "Turn photos into a PDF",
        icon: Icons.image_outlined,
        color: Colors.blueAccent,
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SelectedImagesScreen()),
          );
          if (mounted) context.read<ImagesProvider>().clearImages();
        },
      ),
      PdfTool(
        title: "pdf_to_image".tr(),
        subtitle: "Save pages as photos",
        icon: Icons.insert_drive_file_outlined,
        color: Colors.orangeAccent,
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PdfToImageHomeScreen()),
          );
          if (mounted) context.read<PdfToImageProvider>().clearAll();
        },
      ),
      PdfTool(
        title: "split_pdf".tr(),
        subtitle: "Separate selected pages",
        icon: Icons.content_cut_rounded,
        color: Colors.redAccent,
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PdfSplitterScreen()),
          );
          if (mounted) context.read<PdfSplitProvider>().reset();
        },
      ),
      PdfTool(
        title: "merge_pdf".tr(),
        subtitle: "Combine PDFs together",
        icon: Icons.layers_outlined,
        color: Colors.teal,
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PdfMergerScreen()),
          );
          if (mounted) context.read<PdfMergerProvider>().clearAll();
        },
      ),
      PdfTool(
        title: "pdf_to_excel".tr(),
        subtitle: "Export tables to XLS",
        icon: Icons.table_chart_outlined,
        color: Colors.green[600]!,
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PdfToExcelScreen()),
          );
          if (mounted) context.read<PdfToExcelProvider>().reset();
        },
      ),
      PdfTool(
        title: "delete_pages".tr(),
        subtitle: "Delete pages you choose",
        icon: Icons.delete_outline,
        color: Colors.pinkAccent,
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PdfPageDeleteScreen()),
          );
          if (mounted) context.read<PdfPageDeleteProvider>().reset();
        },
      ),
      PdfTool(
        title: "compress_pdf".tr(),
        subtitle: "Make a smaller file",
        icon: Icons.compress_rounded,
        color: Colors.deepPurpleAccent,
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PdfCompressorScreen()),
          );
          if (mounted) context.read<PdfCompressorProvider>().reset();
        },
      ),
      PdfTool(
        title: "pdf_to_word".tr(),
        subtitle: "Convert PDF to DOCX",
        icon: Icons.description_outlined,
        color: Colors.blue[700]!,
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PdfToWordScreen()),
          );
          if (mounted) context.read<PdfToWordProvider>().reset();
        },
      ),
      PdfTool(
        title: "pdf_presenter".tr(),
        subtitle: "Show as Slideshow",
        icon: Icons.slideshow_rounded,
        color: Colors.deepPurple[400]!,
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PdfPresenterScreen()),
          );
          if (mounted) context.read<PdfPresenterProvider>().reset();
        },
      ),
      PdfTool(
        title: "lock_unlock".tr(),
        subtitle: "Secure your PDF",
        icon: Icons.lock_outline_rounded,
        color: Colors.blueGrey,
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PdfSecurityScreen()),
          );
          if (mounted) context.read<PdfSecurityProvider>().reset();
        },
      ),
      PdfTool(
        title: "organize_pages".tr(),
        subtitle: "Rotate & Reorder",
        icon: Icons.dashboard_customize_rounded,
        color: Colors.amber,
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PdfOrganizeScreen()),
          );
          if (mounted) context.read<PdfOrganizeProvider>().reset();
        },
      ),
      PdfTool(
        title: "watermark".tr(),
        subtitle: "Add text to pages",
        icon: Icons.branding_watermark_rounded,
        color: Colors.cyan,
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PdfWatermarkScreen()),
          );
          if (mounted) context.read<PdfWatermarkProvider>().reset();
        },
      ),
      PdfTool(
        title: "scan_document".tr(),
        subtitle: "Camera to PDF",
        icon: Icons.document_scanner_rounded,
        color: Colors.blueAccent,
        onTap: () async {
          final success = await context.read<PdfScannerProvider>().startScan(context);
          if (success) {
            AdHelper.showInterstitialAd(() {});
          }
        },
      ),
    ];
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryTextColor = isDark
        ? Colors.white
        : const Color(0xFF1E293B); // Dark Navy

    final filteredTools = _allTools.where((t) {
      final query = _searchQuery.toLowerCase();
      return t.title.toLowerCase().contains(query) ||
          t.subtitle.toLowerCase().contains(query);
    }).toList();

    return Column(
      children: [
        // Static Header Area (Always visible)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(25),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "PDF Quant",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: primaryTextColor,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              CircleAvatar(
                backgroundColor: theme.cardColor,
                radius: 20,
                child: IconButton(
                  icon: Icon(
                    Icons.settings_rounded,
                    color: theme.iconTheme.color,
                  ),
                  iconSize: 20,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // Scrollable Content
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Text
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "YOUR DOCUMENTS, IN ORDER",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: theme.hintColor.withAlpha(150),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "What would you like to do?",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: primaryTextColor,
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Search Bar
                      Container(
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.dividerColor.withAlpha(
                              isDark ? 50 : 20,
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(isDark ? 40 : 5),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) =>
                              setState(() => _searchQuery = val),
                          style: TextStyle(color: theme.colorScheme.onSurface),
                          decoration: InputDecoration(
                            hintText: "Search tools or files",
                            hintStyle: TextStyle(
                              color: theme.hintColor.withAlpha(120),
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: theme.hintColor,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Quick Tools
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Quick tools",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: primaryTextColor,
                        ),
                      ),
                      Text(
                        "${filteredTools.length} available",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: theme.hintColor,
                        ),
                      ),
                    ],
                  ),
                ),

                if (filteredTools.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Center(
                      child: Text(
                        "No tools found matching '$_searchQuery'",
                        style: TextStyle(color: theme.hintColor),
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GridView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 2.1,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                      itemCount: filteredTools.length,
                      itemBuilder: (context, index) {
                        return _ToolCardWidget(
                          tool: filteredTools[index],
                          theme: theme,
                          isDark: isDark,
                        );
                      },
                    ),
                  ),

                // Recent Documents Preview
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 32, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Recent documents",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: primaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Consumer<FileHistoryProvider>(
                    builder: (context, historyProvider, child) {
                      final recentFiles = historyProvider.filePaths
                          .take(3)
                          .toList();

                      if (recentFiles.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: theme.dividerColor.withAlpha(20),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              "No recent documents yet",
                              style: TextStyle(color: theme.hintColor),
                            ),
                          ),
                        );
                      }

                      return Column(
                        children: recentFiles
                            .map(
                              (path) => _RecentFileCard(
                                path: path,
                                theme: theme,
                                isDark: isDark,
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
                ),

                // Advertisement Section
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 24, 20, 8),
                  child: Text(
                    "ADVERTISEMENT",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: Colors.grey,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: theme.cardColor,
                      border: Border.all(
                        color: theme.dividerColor.withAlpha(20),
                      ),
                    ),
                    child: const BannerAdWidget(),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------------------
// RECENT TAB
// --------------------------------------------------------------------------

class _RecentTab extends StatelessWidget {
  const _RecentTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Text(
            "Recent Documents",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
              letterSpacing: -0.5,
            ),
          ),
        ),
        Expanded(
          child: Consumer<FileHistoryProvider>(
            builder: (context, historyProvider, child) {
              final files = historyProvider.filePaths;

              if (files.isEmpty) {
                return Center(
                  child: Text(
                    "No recent documents found.",
                    style: TextStyle(color: theme.hintColor),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: files.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _RecentFileCard(
                      path: files[index],
                      theme: theme,
                      isDark: isDark,
                      onDelete: () => historyProvider.removeFile(files[index]),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------------------
// TOOLS & SETTINGS TAB
// --------------------------------------------------------------------------

class _ToolsTab extends StatelessWidget {
  const _ToolsTab();

  void _rateUs(BuildContext context) async {
    const String playStoreUrl =
        "https://play.google.com/store/apps/details?id=com.johurasoftone.pdfquant";
    final Uri url = Uri.parse(playStoreUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        Fluttertoast.showToast(
          msg: "Could not open Play Store",
          backgroundColor: Colors.red,
        );
      }
    }
  }

  void _shareApp() {
    const String playStoreUrl =
        "https://play.google.com/store/apps/details?id=com.johurasoftone.pdfquant";
    SharePlus.instance.share(
      ShareParams(
        text:
            "Check out this amazing PDF Quant: Editor & Manager app! Download now: $playStoreUrl",
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Text(
            "Settings & More",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
              letterSpacing: -0.5,
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              _buildSettingsCard(
                theme: theme,
                icon: Icons.settings_rounded,
                title: "App Settings",
                subtitle: "Theme, Storage and Preferences",
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
              _buildSettingsCard(
                theme: theme,
                icon: Icons.privacy_tip_rounded,
                title: "Legal & Privacy",
                subtitle: "Read our privacy policy",
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PrivacyPolicyScreen(),
                  ),
                ),
              ),
              _buildSettingsCard(
                theme: theme,
                icon: Icons.star_rounded,
                title: "Rate Us",
                subtitle: "Love the app? Rate us on Play Store",
                onTap: () => _rateUs(context),
              ),
              _buildSettingsCard(
                theme: theme,
                icon: Icons.share_rounded,
                title: "Share App",
                subtitle: "Share PDF Quant with your friends",
                onTap: () => _shareApp(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsCard({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withAlpha(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(
              theme.brightness == Brightness.dark ? 40 : 5,
            ),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withAlpha(20),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: theme.colorScheme.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: theme.hintColor),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}

// --------------------------------------------------------------------------
// REUSABLE WIDGETS
// --------------------------------------------------------------------------

class _ToolCardWidget extends StatelessWidget {
  final PdfTool tool;
  final ThemeData theme;
  final bool isDark;

  const _ToolCardWidget({
    required this.tool,
    required this.theme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: tool.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.dividerColor.withAlpha(isDark ? 50 : 20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 40 : 5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon Container
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: tool.color.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(tool.icon, color: tool.color, size: 24),
            ),
            const SizedBox(width: 12),
            // Text Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    tool.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tool.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.hintColor,
                      fontSize: 10,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentFileCard extends StatelessWidget {
  final String path;
  final ThemeData theme;
  final bool isDark;
  final VoidCallback? onDelete;

  const _RecentFileCard({
    required this.path,
    required this.theme,
    required this.isDark,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    final name = path.split(Platform.pathSeparator).last;

    // Attempt to get file metadata safely
    String metadataText = "Unknown format";
    try {
      if (file.existsSync()) {
        final stat = file.statSync();
        final date = DateFormat('MMM d, yyyy').format(stat.modified);
        final sizeMb = (stat.size / (1024 * 1024)).toStringAsFixed(1);
        final extension = name.split('.').last.toUpperCase();
        metadataText = "$extension • $sizeMb MB • $date";
      }
    } catch (e) {
      metadataText = "Local Document";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.dividerColor.withAlpha(isDark ? 50 : 20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 40 : 5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blueAccent.withAlpha(20),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.insert_drive_file_rounded,
            color: Colors.blueAccent,
          ),
        ),
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF1E293B),
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            metadataText,
            style: TextStyle(fontSize: 11, color: theme.hintColor),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onDelete != null)
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                  size: 20,
                ),
                onPressed: onDelete,
              ),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ],
        ),
        onTap: () {
          if (file.existsSync()) {
            OpenFilex.open(path);
          } else {
            Fluttertoast.showToast(
              msg: "File no longer exists",
              backgroundColor: Colors.red,
            );
          }
        },
      ),
    );
  }
}
