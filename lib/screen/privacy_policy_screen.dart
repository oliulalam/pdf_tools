import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fluttertoast/fluttertoast.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const String _onlinePolicyUrl =
      'https://johurasoft.github.io/pdf-quant-privacy-policy/';

  Future<void> _launchURL(BuildContext context) async {
    final Uri url = Uri.parse(_onlinePolicyUrl);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      if (context.mounted) {
        Fluttertoast.showToast(
          msg: "Error opening URL: $e",
          backgroundColor: Colors.red,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text("Legal & Privacy", style: theme.appBarTheme.titleTextStyle),
        actions: [
          IconButton(
            icon: const Icon(Icons.language_rounded),
            tooltip: "View Online",
            onPressed: () => _launchURL(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TL;DR Summary Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 28),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Quick Summary",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildSummaryPoint(
                    context,
                    "📱",
                    "All PDF processing happens on your device — no uploads",
                  ),
                  _buildSummaryPoint(
                    context,
                    "🔒",
                    "Your files are never accessed by us or third parties",
                  ),
                  _buildSummaryPoint(
                    context,
                    "📢",
                    "Ads are shown via Google AdMob with your consent",
                  ),
                  _buildSummaryPoint(
                    context,
                    "❌",
                    "We do not sell your personal information",
                  ),
                  _buildSummaryPoint(
                    context,
                    "🛡️",
                    "Your documents stay private — we never see them",
                  ),
                ],
              ),
            ),

            _buildIntroText(context),

            // ───── SECTION 1 ─────
            _buildSection(
              context,
              "1. Information Collection and Use",
              "PDF Quant: Editor & Manager is designed to prioritize your privacy by processing your files locally on your device. All core file operations — including PDF compression, merging, splitting, page deletion, image-to-PDF conversion, PDF-to-image conversion, PDF-to-Word conversion, PDF-to-Excel conversion, and Document Scanning — are performed locally.\n\n"
                  "We do not upload your files or personal documents to any server. The information the app stores, entirely on your own device, includes:\n\n"
                  "• App settings (Light/Dark mode theme preferences) stored locally via 'shared_preferences'\n"
                  "• Recent Documents History: the names and file paths of PDFs you create or modify, stored locally so you can find them again in the app. This list never leaves your device and can be cleared at any time (see Section 12).\n"
                  "• Ad-related identifiers collected by Google AdMob (see Section 4)\n\n"
                  "Document Scanner & Text Recognition (OCR): To convert physical documents to PDF and extract text for Word or Excel files, we use Google ML Kit Document Scanner and Text Recognition. These Machine Learning models run locally on your device. Your documents are NEVER sent to the cloud for text extraction.\n\n"
                  "Photo/Image Access: When you use the Image to PDF feature, the app uses 'image_picker' to let you select photos from your device gallery. These images are processed entirely on your device and are NEVER uploaded, transmitted, or stored by us.\n\n"
                  "We do NOT upload, transmit, or have remote access to:\n"
                  "• Your PDF file contents\n"
                  "• Contact details, email addresses, or phone numbers\n"
                  "• Photos or images beyond what you explicitly select for conversion",
            ),

            // ───── SECTION 2 ─────
            _buildSection(
              context,
              "2. File Processing (Secure On-Device Processing)",
              "To ensure your privacy and security, all PDF operations — including merging, splitting, compressing, scanning, and conversions (Word/Excel/Images) — occur locally on your mobile device. \n\n"
                  "• NO CLOUD UPLOADS: Your files are NEVER uploaded to any remote server or third-party cloud service.\n"
                  "• ON-DEVICE AI/OCR: Our document scanning and optical character recognition (OCR) uses Google ML Kit which runs on your device without sending any document content to Google servers.\n"
                  "• NO DATA RETENTION: We do not store or keep copies of your documents on any server. Temporary files created during processing should be cleared by your system automatically.\n"
                  "• FULL PRIVACY: We have absolutely no remote access to the content of your documents at any time.",
            ),

            // ───── SECTION 3 ─────
            _buildSection(
              context,
              "3. Permissions and Their Purpose",
              "PDF Quant: Editor & Manager only requests permissions that are essential for its core functionality:\n\n"
                  "• File Selection & Storage: We use the system-managed file picker to allow you to select PDF files and images from your device for processing. This permission is used strictly to read the files you choose and to save the final results back to your device's storage. On older Android devices (API 29 and below), we may request 'WRITE_EXTERNAL_STORAGE' to ensure files can be saved correctly; this permission is not requested on modern Android versions.\n"
                  "• Image Selection: We use 'image_picker' for converting photos to PDF. These images are processed locally and are never transmitted beyond your device.\n"
                  "• Camera Access: The app may request camera access through Google ML Kit Document Scanner for you to scan physical documents directly into PDF format.\n"
                  "• Internet Access & Advertising ID (AD_ID): Required for Google AdMob to display advertisements and for the UMP consent management platform. The Advertising ID can be reset or opted out of via Android Settings → Google → Ads.\n\n"
                  "Note: On Android 13+ devices, the app uses the official System Photo Picker, which ensures we do not have broad access to your media library — only to the specific photos you select. On older devices, we use the Storage Access Framework (SAF), which also restricts app access to only the files you explicitly pick.",
            ),

            // ───── SECTION 4 ─────
            _buildSection(
              context,
              "4. Advertisements (Google AdMob)",
              "We use Google AdMob to display banner and interstitial advertisements. AdMob may collect certain data including:\n\n"
                  "• Device identifiers (e.g., Advertising ID / AD_ID)\n"
                  "• Coarse Location (estimated from IP address) for ad targeting\n"
                  "• Usage data and crash logs for ad personalization\n\n"
                  "We use Google's User Messaging Platform (UMP) to request your consent (where legally required) before displaying personalized ads.\n\n"
                  "For more information, see Google's Privacy Policy:\nhttps://policies.google.com/privacy",
            ),

            // ───── SECTION 5 ─────
            _buildSection(
              context,
              "5. GDPR & User Consent (UMP)",
              "For users in the European Economic Area (EEA) and UK, in accordance with GDPR:\n\n"
                  "• On first launch, you will see a consent dialog\n"
                  "• You may Accept or Decline personalized advertisements\n"
                  "• Your choice is stored locally and respected immediately\n"
                  "• You may change your preference at any time from app Settings\n\n"
                  "Declining personalized ads does NOT affect any app functionality. All PDF features work regardless of your ad choice.",
            ),

            // ───── SECTION 6 ─────
            _buildSection(
              context,
              "6. Third-Party Services",
              "The app uses the following third-party services which have their own Privacy Policies:\n\n"
                  "• Google Play Services\n"
                  "• Google AdMob — https://policies.google.com/privacy\n"
                  "• Google User Messaging Platform (UMP)\n"
                  "• Google ML Kit (for on-device Text Recognition/OCR)\n\n"
                  "These services may collect information used to identify you as described in their respective policies.",
            ),

            // ───── SECTION 7 ─────
            _buildSection(
              context,
              "7. File Sharing",
              "When you use the 'Share' feature, your selected files are passed directly to third-party applications of your choice (e.g., WhatsApp, Gmail, Bluetooth). Once shared, the data is subject to the privacy policy of the respective application. We have no control over how third-party apps handle your shared data.",
            ),

            // ───── SECTION 8 ─────
            _buildSection(
              context,
              "8. Data Storage & Security",
              "• App settings and Recent Documents history (file names and paths) are stored locally on your device only, and are never uploaded anywhere.\n"
                  "• PDF files are processed in temporary storage and deleted immediately after.\n"
                  "• Uninstalling the app removes all locally stored data.\n"
                  "• We do not operate any servers that store your data\n"
                  "• No user accounts or passwords are required\n\n"
                  "While we take all reasonable steps to protect your data, no method of electronic storage is 100% secure.",
            ),

            // ───── SECTION 9 ─────
            _buildSection(
              context,
              "9. Children's Privacy (COPPA)",
              "PDF Quant: Editor & Manager is intended for general audiences and is not designed specifically for children. We do not knowingly collect data from children under the age of 13.\n\n"
                  "If you are a parent or guardian and believe your child has provided us with personal information, please contact us immediately at the email below so we can take the necessary actions.",
            ),

            // ───── SECTION 10 ─────
            _buildSection(
              context,
              "10. Data We Do NOT Collect",
              "We want to be fully transparent about what we do not collect:\n\n"
                  "• We do NOT sell or rent your personal information to any third party\n"
                  "• We do NOT upload or transmit your PDF file contents to any server (file names/paths are kept locally only, as described in Sections 1 and 8)\n"
                  "• We do NOT collect contact details, emails, or phone numbers\n"
                  "• We do NOT collect location data beyond estimated location from IP address by AdMob\n"
                  "• We do NOT share data for advertising purposes beyond AdMob's own policy",
            ),

            // ───── SECTION 11 ─────
            _buildSection(
              context,
              "11. International Data Transfers",
              "Your data may be transferred to and processed in countries outside your own, including the United States, by Google's services (AdMob, UMP).\n\n"
                  "Google ensures adequate safeguards through Standard Contractual Clauses. For EEA/UK users, your UMP consent covers these transfers.\n\n"
                  "For details: https://policies.google.com/privacy",
            ),

            // ───── SECTION 12 ─────
            _buildSection(
              context,
              "12. Your Rights (GDPR & CCPA)",
              "Depending on your location, you may have the following rights:\n\n"
                  "• Right to Access: We do not store personal data on our servers. For data collected by Google AdMob (such as Advertising ID), please refer to Google's data access tools at myaccount.google.com\n"
                  "• Right to Deletion: You can use the 'Clear History' option in the Recent Documents / My Files screen to remove the local list of file names and paths at any time, or uninstall the app to delete all local app data.\n"
                  "• Right to Withdraw Consent: Use the 'Privacy Options' button at the bottom of the Settings screen to change your ad consent preferences\n"
                  "• Right to Opt-Out: Android Settings → Google → Ads → Opt out of Ads Personalization\n"
                  "• Right to Object: Decline personalized ads at any time via the consent form or device settings\n\n"
                  "California residents (CCPA): We do not sell your personal information.\n\n"
                  "To exercise your rights, contact us at the email below.",
            ),

            // ───── SECTION 13 ─────
            _buildSection(
              context,
              "13. Changes to This Privacy Policy",
              "We may update our Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page and updating the 'Last Updated' date.\n\n"
                  "You are advised to review this page periodically. Changes are effective immediately after they are posted.",
            ),

            // ───── SECTION 14 ─────
            _buildSection(
              context,
              "14. Contact Us",
              "If you have any questions, concerns, or requests regarding this Privacy Policy, please contact us:\n\n"
                  "Email: johurasoft@gmail.com\n"
                  "Subject: PDF Quant — Privacy Request\n"
                  "Response Time: Within 30 days\n\n"
                  "Note: Since we do not store any personal data on our servers, data-related requests will be directed to the respective third-party service (e.g., Google AdMob) as applicable.",
            ),

            const SizedBox(height: 16),
            Center(
              child: OutlinedButton.icon(
                onPressed: () => _launchURL(context),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text("Open Online Policy"),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Center(
              child: Column(
                children: [
                  Text(
                    "Effective Date: June 1, 2026",
                    style: TextStyle(color: theme.hintColor, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Last Updated: October 2026",
                    style: TextStyle(color: theme.hintColor, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroText(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Text(
        "This page informs you of our policies regarding the collection, use, and disclosure of personal information when you use PDF Quant: Editor & Manager. By using this app, you agree to the collection and use of information in accordance with this policy.",
        style: TextStyle(
          fontSize: 14,
          color: theme.colorScheme.onSurface.withAlpha(180),
          height: 1.6,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _buildSummaryPoint(BuildContext context, String emoji, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onPrimaryContainer,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withAlpha(200),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
