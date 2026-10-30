import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf_toolkit/provider/pdf_presenter_provider/pdf_presenter_provider.dart';
import 'package:pdf_toolkit/utils/ad_helper.dart';
import 'package:pdf_toolkit/widgets/banner_ad_widget.dart';
import 'package:pdf_toolkit/widgets/tool_ui_components.dart';
import 'package:pdfx/pdfx.dart';
import 'package:provider/provider.dart';

import 'package:wakelock_plus/wakelock_plus.dart';

class PdfPresenterScreen extends StatefulWidget {
  const PdfPresenterScreen({super.key});

  @override
  State<PdfPresenterScreen> createState() => _PdfPresenterScreenState();
}

class _PdfPresenterScreenState extends State<PdfPresenterScreen> {
  PdfControllerPinch? _pdfController;
  bool _isPresenting = false;
  String _orientation = 'Landscape';
  bool _keepAwake = true;

  @override
  void dispose() {
    _restoreSystemUI();
    _pdfController?.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  void _startPresentation(String filePath) {
    _pdfController = PdfControllerPinch(
      document: PdfDocument.openFile(filePath),
    );

    setState(() {
      _isPresenting = true;
    });

    if (_keepAwake) {
      WakelockPlus.enable();
    }

    if (_orientation == 'Landscape') {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeRight,
        DeviceOrientation.landscapeLeft,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _exitPresentation() {
    _restoreSystemUI();
    WakelockPlus.disable();
    setState(() {
      _isPresenting = false;
    });
  }

  void _restoreSystemUI() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: !_isPresenting,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isPresenting) {
          _exitPresentation();
        }
      },
      child: Consumer<PdfPresenterProvider>(
        builder: (context, provider, child) {
          if (_isPresenting && provider.selectedFile != null) {
            return _buildPresentationView(theme);
          }

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
                        ToolHeader(
                          title: "Present PDF",
                          subtitle:
                              "Set your starting slide and display preferences.",
                          icon: Icons.slideshow_rounded,
                          color: Colors.deepPurple[400]!,
                        ),

                        const SectionHeader(title: "Selected deck"),
                        if (hasFile)
                          SelectedFileCard(
                            file: provider.selectedFile!,
                            onChange: provider.isLoading
                                ? null
                                : () => provider.pickFile(),
                            badgeColor: Colors.deepPurple[400]!,
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
                                        style: TextStyle(
                                          color: theme.hintColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                        if (hasFile) ...[
                          const SectionHeader(
                            title: "Preview & starting page",
                            trailingText: "Start at page 1",
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            height: 180,
                            decoration: BoxDecoration(
                              color: Colors.deepPurple[900],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.slideshow_rounded,
                                size: 64,
                                color: Colors.white24,
                              ),
                            ),
                          ),

                          const SectionHeader(
                            title: "Display settings",
                            trailingText: "Ready for screen sharing",
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: theme.cardColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: theme.dividerColor.withAlpha(20),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.screen_rotation_rounded,
                                            size: 18,
                                            color: theme.hintColor,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            "Orientation",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color:
                                                  theme.colorScheme.onSurface,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          GestureDetector(
                                            onTap: () => setState(
                                              () => _orientation = 'Landscape',
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color:
                                                    _orientation == 'Landscape'
                                                    ? Colors.deepPurple[400]!
                                                          .withAlpha(20)
                                                    : Colors.transparent,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color:
                                                      _orientation ==
                                                          'Landscape'
                                                      ? Colors.deepPurple[400]!
                                                      : theme.dividerColor,
                                                ),
                                              ),
                                              child: Text(
                                                "Landscape",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                  color:
                                                      _orientation ==
                                                          'Landscape'
                                                      ? Colors.deepPurple[400]
                                                      : theme.hintColor,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          GestureDetector(
                                            onTap: () => setState(
                                              () => _orientation = 'Portrait',
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color:
                                                    _orientation == 'Portrait'
                                                    ? Colors.deepPurple[400]!
                                                          .withAlpha(20)
                                                    : Colors.transparent,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color:
                                                      _orientation == 'Portrait'
                                                      ? Colors.deepPurple[400]!
                                                      : theme.dividerColor,
                                                ),
                                              ),
                                              child: Text(
                                                "Portrait",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                  color:
                                                      _orientation == 'Portrait'
                                                      ? Colors.deepPurple[400]
                                                      : theme.hintColor,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.lightbulb_outline_rounded,
                                            size: 18,
                                            color: theme.hintColor,
                                          ),
                                          const SizedBox(width: 8),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "Keep screen awake",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  color: theme
                                                      .colorScheme
                                                      .onSurface,
                                                ),
                                              ),
                                              Text(
                                                "Not supported offline",
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.redAccent
                                                      .withAlpha(150),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      Switch(
                                        value: _keepAwake,
                                        activeColor: Colors.deepPurple[400],
                                        onChanged: (val) {
                                          // Visual only for now
                                          setState(() => _keepAwake = val);
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
                if (hasFile)
                  BottomActionBar(
                    actionText: "Start presentation",
                    isLoading: provider.isLoading,
                    color: Colors.deepPurple[400]!,
                    onAction: () =>
                        _startPresentation(provider.selectedFile!.path),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPresentationView(ThemeData theme) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_pdfController != null)
            PdfViewPinch(
              controller: _pdfController!,
              scrollDirection: Axis.horizontal,
              backgroundDecoration: const BoxDecoration(color: Colors.black),
            ),

          Positioned(
            top: 16,
            left: 16,
            child: SafeArea(
              child: FloatingActionButton.small(
                onPressed: _exitPresentation,
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
                elevation: 0,
                child: const Icon(Icons.close_rounded),
              ),
            ),
          ),

          Positioned(
            bottom: 16,
            right: 16,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: PdfPageNumber(
                  controller: _pdfController!,
                  builder: (_, loadingState, page, pagesCount) => Text(
                    '$page / ${pagesCount ?? 0}',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
