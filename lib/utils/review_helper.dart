import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReviewHelper {
  static const String _actionCountKey = 'app_action_count';
  static const int _actionThreshold = 5; // Request review after 5 successful actions

  static Future<void> incrementActionAndRequestReview() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int currentCount = prefs.getInt(_actionCountKey) ?? 0;
      currentCount++;

      await prefs.setInt(_actionCountKey, currentCount);

      if (currentCount == _actionThreshold) {
        final InAppReview inAppReview = InAppReview.instance;
        if (await inAppReview.isAvailable()) {
          await inAppReview.requestReview();
        }
      }
    } catch (e) {
      debugPrint("Error requesting review: $e");
    }
  }
}
