import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_toolkit/provider/file_history_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:pdf_toolkit/widgets/banner_ad_widget.dart';
import 'package:pdf_toolkit/screen/pdf_viewer_screen/pdf_viewer_screen.dart';

enum SortOption { dateDesc, dateAsc, nameAsc, nameDesc }

class MyFilesScreen extends StatefulWidget {
  const MyFilesScreen({super.key});

  @override
  State<MyFilesScreen> createState() => _MyFilesScreenState();
}

class _MyFilesScreenState extends State<MyFilesScreen> {
  String _searchQuery = "";
  SortOption _sortOption = SortOption.dateDesc;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Recent Documents",
          style: theme.appBarTheme.titleTextStyle,
        ),
        elevation: 0,
        actions: [
          PopupMenuButton<SortOption>(
            icon: const Icon(Icons.sort_rounded),
            onSelected: (option) => setState(() => _sortOption = option),
            itemBuilder: (context) => const [
              PopupMenuItem(value: SortOption.dateDesc, child: Text("Newest first")),
              PopupMenuItem(value: SortOption.dateAsc, child: Text("Oldest first")),
              PopupMenuItem(value: SortOption.nameAsc, child: Text("Name (A-Z)")),
              PopupMenuItem(value: SortOption.nameDesc, child: Text("Name (Z-A)")),
            ],
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_sweep_rounded,
              color: Colors.redAccent,
            ),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Clear History?"),
                  content: const Text(
                    "This will only clear the list, not delete the actual files.",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: () {
                        context.read<FileHistoryProvider>().clearHistory();
                        Navigator.pop(context);
                      },
                      child: const Text(
                        "Clear",
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search files...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.cardColor,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
            ),
          ),
          Expanded(
            child: Consumer<FileHistoryProvider>(
              builder: (context, provider, child) {
                if (provider.filePaths.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.folder_open_rounded,
                          size: 80,
                          color: theme.hintColor.withAlpha(50),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "No files created yet",
                          style: TextStyle(color: theme.hintColor),
                        ),
                      ],
                    ),
                  );
                }
                
                // Filter and sort
                List<String> displayedFiles = provider.filePaths.where((path) {
                  final name = path.split(Platform.pathSeparator).last.toLowerCase();
                  return name.contains(_searchQuery);
                }).toList();

                displayedFiles.sort((a, b) {
                  final fileA = File(a);
                  final fileB = File(b);
                  
                  if (_sortOption == SortOption.nameAsc || _sortOption == SortOption.nameDesc) {
                    final nameA = a.split(Platform.pathSeparator).last.toLowerCase();
                    final nameB = b.split(Platform.pathSeparator).last.toLowerCase();
                    return _sortOption == SortOption.nameAsc ? nameA.compareTo(nameB) : nameB.compareTo(nameA);
                  } else {
                    // Date sort
                    try {
                      final statA = fileA.statSync().modified;
                      final statB = fileB.statSync().modified;
                      return _sortOption == SortOption.dateDesc ? statB.compareTo(statA) : statA.compareTo(statB);
                    } catch (_) {
                      return 0;
                    }
                  }
                });

                if (displayedFiles.isEmpty) {
                  return const Center(child: Text("No files match your search"));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: displayedFiles.length,
                  itemBuilder: (context, index) {
                    final path = displayedFiles[index];
                    return _FileItemCard(
                      path: path,
                      theme: theme,
                      onRemove: () => provider.removeFile(path),
                    );
                  },
                );
              },
            ),
          ),
          const BannerAdWidget(),
        ],
      ),
    );
  }
}

class _FileItemCard extends StatefulWidget {
  final String path;
  final ThemeData theme;
  final VoidCallback onRemove;

  const _FileItemCard({
    required this.path,
    required this.theme,
    required this.onRemove,
  });

  @override
  State<_FileItemCard> createState() => _FileItemCardState();
}

class _FileItemCardState extends State<_FileItemCard> {

  void _renameFile(BuildContext context, String currentFileName) {
    final TextEditingController controller = TextEditingController(text: currentFileName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Rename File"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: "Enter new name",
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != currentFileName) {
                final dir = p.dirname(widget.path);
                final ext = p.extension(widget.path);
                final newPath = p.join(dir, newName.endsWith(ext) ? newName : '$newName$ext');
                
                final success = await context.read<FileHistoryProvider>().renameFile(widget.path, newPath);
                if (mounted) {
                  if (success) {
                    Navigator.pop(context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to rename file.')),
                    );
                  }
                }
              }
            },
            child: const Text("Rename"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final file = File(widget.path);

    return FutureBuilder<FileStat>(
      future: file.stat(),
      builder: (context, snapshot) {
        // Even if file doesn't exist, we handle it gracefully
        final exists =
            snapshot.hasData &&
            snapshot.data!.type != FileSystemEntityType.notFound;
        if (!exists && snapshot.connectionState == ConnectionState.done) {
          return const SizedBox.shrink();
        }

        final fileName = widget.path.split(Platform.pathSeparator).last;
        String subtitle = "Loading...";

        if (snapshot.hasData) {
          final size = (snapshot.data!.size / 1024).toStringAsFixed(1);
          final date = DateFormat(
            'dd MMM yyyy, hh:mm a',
          ).format(snapshot.data!.modified);
          subtitle = "$size KB • $date";
        }

        return Card(
          color: widget.theme.cardColor,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: const CircleAvatar(
              backgroundColor: Colors.orangeAccent,
              child: Icon(Icons.picture_as_pdf, color: Colors.white),
            ),
            title: Text(
              fileName,
              style: TextStyle(
                color: widget.theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: widget.theme.hintColor, fontSize: 12),
                ),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PdfViewerScreen(
                    path: widget.path,
                    title: fileName,
                  ),
                ),
              );
            },
            trailing: PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: widget.theme.hintColor),
              color: widget.theme.cardColor,
              onSelected: (value) async {
                if (value == 'share') {
                  await SharePlus.instance.share(
                    ShareParams(files: [XFile(widget.path)]),
                  );
                } else if (value == 'rename') {
                  _renameFile(context, fileName);
                } else if (value == 'delete') {
                  widget.onRemove();
                } else if (value == 'delete_file') {
                  widget.onRemove();
                  try {
                    await file.delete();
                  } catch (e) {
                    debugPrint("Failed to delete file from storage: $e");
                  }
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'share',
                  child: Text(
                    "Share",
                    style: TextStyle(color: widget.theme.colorScheme.onSurface),
                  ),
                ),
                PopupMenuItem(
                  value: 'rename',
                  child: Text(
                    "Rename",
                    style: TextStyle(color: widget.theme.colorScheme.onSurface),
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    "Remove from list",
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete_file',
                  child: Text(
                    "Delete File permanently",
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
