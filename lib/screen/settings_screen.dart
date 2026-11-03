import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:pdf_toolkit/provider/file_history_provider.dart';
import 'package:pdf_toolkit/provider/theme_provider.dart';
import 'package:pdf_toolkit/screen/privacy_policy_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _showPrivacyOptions(BuildContext context) async {
    ConsentInformation.instance.getPrivacyOptionsRequirementStatus().then((
      status,
    ) {
      if (status == PrivacyOptionsRequirementStatus.required) {
        ConsentForm.showPrivacyOptionsForm((FormError? error) {
          if (error != null) {
            Fluttertoast.showToast(
              msg: "Error showing privacy options: ${error.message}",
              backgroundColor: Colors.red,
            );
          }
        });
      } else {
        Fluttertoast.showToast(
          msg: "Privacy options are not required for your region.",
          backgroundColor: Colors.indigo,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text("Settings", style: theme.appBarTheme.titleTextStyle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: Icon(
                isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                color: Colors.orangeAccent,
              ),
              title: const Text("App Theme"),
              subtitle: Text(
                isDarkMode ? "Dark Mode Enabled" : "Light Mode Enabled",
              ),
              trailing: Switch(
                value: isDarkMode,
                onChanged: (value) {
                  themeProvider.toggleTheme(value);
                },
                activeTrackColor: Colors.orangeAccent,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.language_rounded,
                color: Colors.greenAccent,
              ),
              title: const Text("Language"),
              subtitle: const Text("English"),
              trailing: DropdownButton<String>(
                value: 'en',
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'en', child: Text("English")),
                ],
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    context.setLocale(Locale(newValue));
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("Clear File History?"),
                    content: const Text(
                      "This will clear the recent files list and internal copies created by the app. Files saved to device storage are unaffected.",
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text("Cancel"),
                      ),
                      TextButton(
                        onPressed: () {
                          context.read<FileHistoryProvider>().clearHistory();
                          Navigator.pop(ctx);
                          Fluttertoast.showToast(msg: "History cleared successfully");
                        },
                        child: const Text(
                          "Clear",
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ],
                  ),
                );
              },
              leading: const Icon(
                Icons.delete_sweep_rounded,
                color: Colors.redAccent,
              ),
              title: const Text("Clear History"),
              subtitle: const Text("Remove cached files and recent history"),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                );
              },
              leading: const Icon(
                Icons.policy_rounded,
                color: Colors.teal,
              ),
              title: const Text("Privacy Policy"),
              subtitle: const Text("Read our full legal and privacy policy"),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              onTap: () => _showPrivacyOptions(context),
              leading: const Icon(
                Icons.privacy_tip_rounded,
                color: Colors.blueAccent,
              ),
              title: const Text("GDPR Privacy Options"),
              subtitle: const Text("Manage your consent and privacy settings"),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              "More settings will be available in future updates.",
              style: TextStyle(
                color: Theme.of(context).hintColor,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
