import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_toolkit/provider/file_history_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:pdf_toolkit/widgets/banner_ad_widget.dart';
import 'package:pdf_toolkit/utils/open_file_helper.dart';

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
                    "This removes the list and the app's internal copies. Files you saved to your device storage are not deleted.",
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
                  if (_sortOption == SortOption.nameAsc ||
                      _sortOption == SortOption.nameDesc) {
                    final nameA = a.split(Platform.pathSeparator).last.toLowerCase();
                    final nameB = b.split(Platform.pathSeparator).last.toLowerCase();
                    return _sortOption == SortOption.nameAsc
                        ? nameA.compareTo(nameB)
                        : nameB.compareTo(nameA);
                  } else {
                    // Date sort
                    final regExp = RegExp(r'^(\d{13})_');
                    final nameA = a.split(Platform.pathSeparator).last;
                    final nameB = b.split(Platform.pathSeparator).last;
                    final matchA = regExp.firstMatch(nameA);
                    final matchB = regExp.firstMatch(nameB);
                    final timeA = matchA != null ? int.parse(matchA.group(1)!) : 0;
                    final timeB = matchB != null ? int.parse(matchB.group(1)!) : 0;
                    return _sortOption == SortOption.dateDesc
                        ? timeB.compareTo(timeA)
                        : timeA.compareTo(timeB);
                  }
                });

                if (displayedFiles.isEmpty) {
                  return const Center(
                    child: Text("No files match your search"),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  children: [
                    ...displayedFiles.map(
                      (path) => _FileItemCard(
                        path: path,
                        theme: theme,
                        onRemove: () => provider.removeFile(path),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      child: Text(
                        "ADVERTISEMENT",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: BannerAdWidget(placement: AdPlacement.recent),
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
          ),
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
  late final Future<FileStat> _statFuture = File(widget.path).stat();

  void _renameFile(BuildContext context, String currentFileName) {
    final TextEditingController controller =
    TextEditingController(text: currentFileName);
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
                final newPath = p.join(
                  dir,
                  newName.endsWith(ext) ? newName : '$newName$ext',
                );

                final success = await context
                    .read<FileHistoryProvider>()
                    .renameFile(widget.path, newPath);
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

  IconData _getFileIcon(String ext) {
    switch (ext.toLowerCase()) {
      case 'zip':
        return Icons.folder_zip_rounded;
      case 'xlsx':
      case 'xls':
      case 'csv':
        return Icons.table_chart_rounded;
      case 'docx':
      case 'doc':
        return Icons.description_rounded;
      case 'png':
      case 'jpg':
      case 'jpeg':
        return Icons.image_rounded;
      default:
        return Icons.picture_as_pdf_rounded;
    }
  }

  Color _getFileColor(String ext) {
    switch (ext.toLowerCase()) {
      case 'zip':
        return Colors.amber[800]!;
      case 'xlsx':
      case 'xls':
      case 'csv':
        return Colors.green[700]!;
      case 'docx':
      case 'doc':
        return Colors.blue[800]!;
      case 'png':
      case 'jpg':
      case 'jpeg':
        return Colors.teal;
      default:
        return Colors.redAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = File(widget.path);
    final fileName = displayFileName(widget.path);
    final extStr = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : p.extension(widget.path).replaceAll('.', '').toLowerCase();
    final fileIcon = _getFileIcon(extStr);
    final fileColor = _getFileColor(extStr);

    return FutureBuilder<FileStat>(
      future: _statFuture,
      builder: (context, snapshot) {
        // Even if file doesn't exist, we handle it gracefully
        final exists = snapshot.hasData &&
            snapshot.data!.type != FileSystemEntityType.notFound;
        if (!exists && snapshot.connectionState == ConnectionState.done) {
          return const SizedBox.shrink();
        }

        String subtitle = "Loading...";

        if (snapshot.hasData) {
          final sizeKb = (snapshot.data!.size / 1024).toStringAsFixed(1);
          final date = DateFormat('dd MMM yyyy, hh:mm a')
              .format(snapshot.data!.modified);
          subtitle = "${extStr.toUpperCase()} • $sizeKb KB • $date";
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: widget.theme.cardColor,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: CircleAvatar(
                backgroundColor: fileColor.withAlpha(30),
                child: Icon(fileIcon, color: fileColor),
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
                    style: TextStyle(
                      color: widget.theme.hintColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              onTap: () async {
                final exists = await file.exists();
                if (!context.mounted) return;
                if (exists) {
                  openRecentFile(context, widget.path, fileName);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("File not found. Removing from list.")),
                  );
                  widget.onRemove();
                }
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
                      style: TextStyle(
                        color: widget.theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'rename',
                    child: Text(
                      "Rename",
                      style: TextStyle(
                        color: widget.theme.colorScheme.onSurface,
                      ),
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
          ),
        );
      },
    );
  }
}