import 'dart:io';
import 'package:flutter/material.dart';

class ToolAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ToolAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppBar(
      elevation: 0,
      backgroundColor: theme.scaffoldBackgroundColor,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.red[800],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.description_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            "PDF Quant",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.help_outline_rounded,
            color: theme.colorScheme.onSurface,
          ),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Help details are available in the Settings screen.')),
            );
          },
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class ToolHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const ToolHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "PDF TOOL",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.hintColor,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? trailingText;

  const SectionHeader({super.key, required this.title, this.trailingText});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
          if (trailingText != null)
            Text(
              trailingText!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: theme.hintColor,
              ),
            ),
        ],
      ),
    );
  }
}

class SelectedFileCard extends StatelessWidget {
  final File file;
  final String? overrideName;
  final VoidCallback? onChange;
  final String? badgeText;
  final Color? badgeColor;

  const SelectedFileCard({
    super.key,
    required this.file,
    this.overrideName,
    this.onChange,
    this.badgeText = "PDF",
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = overrideName ?? file.path.split(Platform.pathSeparator).last;

    String sizeText = "Unknown size";
    try {
      if (file.existsSync()) {
        final sizeMb = (file.lengthSync() / (1024 * 1024)).toStringAsFixed(1);
        sizeText = "$sizeMb MB";
      }
    } catch (_) {}

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor.withAlpha(20)),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.picture_as_pdf_rounded,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        sizeText,
                        style: TextStyle(fontSize: 12, color: theme.hintColor),
                      ),
                      if (onChange != null) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: onChange,
                          child: Text(
                            "• Change",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[400],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (badgeText != null) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: (badgeColor ?? Colors.redAccent).withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badgeText!,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    color: badgeColor ?? Colors.redAccent,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class BottomActionBar extends StatelessWidget {
  final String actionText;
  final VoidCallback? onAction;
  final bool isLoading;
  final Color color;

  const BottomActionBar({
    super.key,
    required this.actionText,
    required this.onAction,
    this.isLoading = false,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom > 0
            ? MediaQuery.of(context).padding.bottom
            : 16,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: theme.dividerColor.withAlpha(20)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isLoading ? null : onAction,
              style: FilledButton.styleFrom(
                backgroundColor: color,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          actionText,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.shield_outlined,
                size: 14,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                "Files stay on this device",
                style: TextStyle(fontSize: 11, color: theme.hintColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
