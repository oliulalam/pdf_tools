import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:pdf_toolkit/provider/file_history_provider.dart';
import 'package:pdf_toolkit/utils/ad_helper.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PdfScannerProvider extends ChangeNotifier {
  bool _isScanning = false;
  bool get isScanning => _isScanning;

  static const int _freeDailyLimit = 2;

  Future<bool> checkQuotaAndScan(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = DateTime.now().toString().split(' ')[0];
    
    final lastDate = prefs.getString('scan_quota_date') ?? '';
    int todayCount = prefs.getInt('scan_count_today') ?? 0;
    int bonusCount = prefs.getInt('scan_bonus_count') ?? 0;

    // Reset daily count if a new day
    if (lastDate != todayStr) {
      todayCount = 0;
      await prefs.setString('scan_quota_date', todayStr);
      await prefs.setInt('scan_count_today', 0);
    }

    // Check if user has free daily scans or bonus scans available
    if (todayCount < _freeDailyLimit || bonusCount > 0) {
      final success = await _performScan(context);
      if (success) {
        if (todayCount < _freeDailyLimit) {
          await prefs.setInt('scan_count_today', todayCount + 1);
        } else if (bonusCount > 0) {
          await prefs.setInt('scan_bonus_count', bonusCount - 1);
        }
      }
      return success;
    }

    // Daily limit reached - Show Rewarded Ad Opt-in Dialog (Policy Compliant)
    if (context.mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.stars_rounded, color: Colors.amber, size: 28),
              SizedBox(width: 8),
              Text("Free Scan Limit Reached"),
            ],
          ),
          content: const Text(
            "You have used your 2 free daily scans today.\n\nWatch a short video ad to unlock 3 more scans!",
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.play_circle_fill_rounded),
              label: const Text("Watch Video Ad"),
              onPressed: () {
                Navigator.pop(ctx);
                AdHelper.showRewardedAd(
                  onReward: () async {
                    final currentBonus = prefs.getInt('scan_bonus_count') ?? 0;
                    await prefs.setInt('scan_bonus_count', currentBonus + 3);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("🎉 3 Bonus Scans Unlocked!")),
                      );
                      await checkQuotaAndScan(context);
                    }
                  },
                  onUnavailable: () async {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Ad unavailable right now. Enjoy 1 free scan on us!")),
                      );
                      await _performScan(context);
                    }
                  },
                );
              },
            ),
          ],
        ),
      );
    }

    return false;
  }

  Future<bool> startScan(BuildContext context) async {
    return checkQuotaAndScan(context);
  }

  Future<bool> _performScan(BuildContext context) async {
    _isScanning = true;
    notifyListeners();

    try {
      final DocumentScannerOptions options = DocumentScannerOptions(
        mode: ScannerMode.full,
        pageLimit: 100, // Maximum pages per scan
        isGalleryImport: true,
      );

      final documentScanner = DocumentScanner(options: options);
      
      final DocumentScanningResult result = await documentScanner.scanDocument();
      
      if (result.pdf != null && result.pdf!.uri.isNotEmpty) {
        final String scannedPdfPath = result.pdf!.uri;
        final File tempFile = File(scannedPdfPath);
        
        if (await tempFile.exists()) {
          final String? outputPath = await FilePicker.saveFile(
            dialogTitle: 'Save Scanned PDF',
            fileName: 'Scanned_Doc_${DateTime.now().millisecondsSinceEpoch}.pdf',
            type: FileType.custom,
            allowedExtensions: ['pdf'],
            bytes: await tempFile.readAsBytes(),
          );

          if (outputPath != null && context.mounted) {
            context.read<FileHistoryProvider>().addFile(outputPath);
            _isScanning = false;
            notifyListeners();
            return true;
          }
        }
      }
      
      _isScanning = false;
      notifyListeners();
      return false;
      
    } catch (e) {
      debugPrint("Scanner Error: $e");
      _isScanning = false;
      notifyListeners();
      return false;
    }
  }
}
