import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:pdf_toolkit/provider/theme_provider.dart';

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
              subtitle: Text(context.locale.languageCode == 'bn' ? "বাংলা" : "English"),
              trailing: DropdownButton<String>(
                value: context.locale.languageCode,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'en', child: Text("English")),
                  DropdownMenuItem(value: 'bn', child: Text("বাংলা")),
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
