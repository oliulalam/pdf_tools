import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf_toolkit/provider/pdf_security_provider/pdf_security_provider.dart';
import 'package:pdf_toolkit/utils/ad_helper.dart';
import 'package:pdf_toolkit/widgets/banner_ad_widget.dart';
import 'package:pdf_toolkit/widgets/tool_ui_components.dart';
import 'package:provider/provider.dart';

class PdfSecurityScreen extends StatefulWidget {
  const PdfSecurityScreen({super.key});

  @override
  State<PdfSecurityScreen> createState() => _PdfSecurityScreenState();
}

class _PdfSecurityScreenState extends State<PdfSecurityScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _obscureText = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<PdfSecurityProvider>(
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
                      ToolHeader(
                        title: provider.isLocking ? "Lock PDF" : "Unlock PDF",
                        subtitle: provider.isLocking
                            ? "Add a password to secure your document."
                            : "Remove password from a secured PDF.",
                        icon: provider.isLocking
                            ? Icons.lock_outline_rounded
                            : Icons.lock_open_rounded,
                        color: provider.isLocking ? Colors.redAccent : Colors.greenAccent,
                      ),
                      
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: ChoiceChip(
                                label: const Text("Lock"),
                                selected: provider.isLocking,
                                onSelected: (val) => provider.setMode(true),
                                selectedColor: Colors.redAccent.withAlpha(50),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ChoiceChip(
                                label: const Text("Unlock"),
                                selected: !provider.isLocking,
                                onSelected: (val) => provider.setMode(false),
                                selectedColor: Colors.greenAccent.withAlpha(50),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SectionHeader(
                        title: "Selected PDF",
                      ),

                      if (hasFile)
                        SelectedFileCard(
                          file: provider.selectedFile!,
                          onChange: provider.isLoading ? null : () => provider.pickFile(),
                          badgeColor: provider.isLocking ? Colors.redAccent : Colors.greenAccent,
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
                        const SectionHeader(title: "Password"),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.dividerColor),
                          ),
                          child: TextField(
                            controller: _passwordController,
                            obscureText: _obscureText,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: provider.isLocking ? "Enter new password" : "Enter current password",
                              icon: const Icon(Icons.key_rounded),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureText ? Icons.visibility_off : Icons.visibility,
                                  color: theme.hintColor,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscureText = !_obscureText;
                                  });
                                },
                              ),
                            ),
                          ),
                        ),
                        
                        if (provider.isLocking) ...[
                          const SizedBox(height: 8),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: theme.dividerColor),
                            ),
                            child: TextField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureText,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText: "Confirm password",
                                icon: Icon(Icons.lock_outline_rounded),
                              ),
                            ),
                          ),
                        ],

                        if (provider.isLoading) ...[
                          const SizedBox(height: 24),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: LinearProgressIndicator(
                              color: provider.isLocking ? Colors.redAccent : Colors.greenAccent,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            provider.statusMessage ?? "Processing...",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: theme.hintColor),
                          ),
                        ],
                      ]
                    ],
                  ),
                ),
              ),
              if (hasFile)
                BottomActionBar(
                  actionText: provider.isLocking ? "Lock Document" : "Unlock Document",
                  isLoading: provider.isLoading,
                  color: provider.isLocking ? Colors.redAccent : Colors.greenAccent,
                  onAction: () async {
                    if (_passwordController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Please enter a password")),
                      );
                      return;
                    }
                    if (provider.isLocking && _passwordController.text != _confirmPasswordController.text) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Passwords do not match!")),
                      );
                      return;
                    }
                    FocusScope.of(context).unfocus(); // Hide keyboard
                    final success = await provider.processAndSave(
                      context,
                      _passwordController.text,
                    );
                    if (success) {
                      AdHelper.showInterstitialAd(() {});
                      _passwordController.clear();
                    }
                  },
                ),
              if (!hasFile) const BannerAdWidget(),
            ],
          ),
        );
      },
    );
  }
}
