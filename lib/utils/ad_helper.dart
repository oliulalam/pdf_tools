import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:pdf_toolkit/utils/review_helper.dart';

class AdHelper {
  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/6300978111'; // Test ID
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  static String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/1033173712'; // Test ID
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  static InterstitialAd? _interstitialAd;
  static bool _isInterstitialAdLoading = false;
  static int _loadRetryCount = 0;

  static int _clickCount = 0;
  static DateTime? _lastAdTime;
  // Adjusted as per Play Policy requirements for better UX
  static const int _adIntervalClicks = 3; 
  static const int _adIntervalSeconds = 120; // 2 minutes gap

  static Future<void> initializeMobileAdsAndConsent() async {
    final params = ConsentRequestParameters();
    
    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        if (await ConsentInformation.instance.isConsentFormAvailable()) {
          ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
            _initializeAdsIfReady();
          });
        } else {
          _initializeAdsIfReady();
        }
      },
      (FormError error) {
        debugPrint("Consent Error: ${error.message}");
        _initializeAdsIfReady();
      },
    );
  }

  // ValueNotifier to trigger banner ads when consent is obtained
  static final ValueNotifier<bool> adsReady = ValueNotifier(false);

  static Future<void> _initializeAdsIfReady() async {
    final canRequest = await ConsentInformation.instance.canRequestAds();
    if (canRequest) {
      await MobileAds.instance.initialize();
      adsReady.value = true;
      unawaited(loadInterstitialAd());
    }
  }

  static Future<void> preLoadAds() async {
    debugPrint("AdHelper: Pre-loading Interstitial Ad...");
    final completer = Completer<void>();

    // Attempt to load and wait for it
    unawaited(loadInterstitialAd(
      onAdLoaded: () {
        if (!completer.isCompleted) completer.complete();
      },
      onAdFailed: () {
        if (!completer.isCompleted) completer.complete();
      },
    ));

    // Wait for the ad to load OR max 3 seconds to not hold splash too long
    await completer.future.timeout(
      const Duration(seconds: 3),
      onTimeout: () {
        debugPrint(
          "AdHelper: Pre-load wait timeout. Ad will load in background.",
        );
      },
    );
  }

  static Future<void> loadInterstitialAd({
    VoidCallback? onAdLoaded,
    VoidCallback? onAdFailed,
  }) async {
    final canRequest = await ConsentInformation.instance.canRequestAds();
    if (!canRequest) {
      onAdFailed?.call();
      return;
    }

    if (_isInterstitialAdLoading || _interstitialAd != null) {
      debugPrint("AdHelper: Ad already loading or loaded.");
      onAdLoaded?.call();
      return;
    }

    _isInterstitialAdLoading = true;
    debugPrint(
      "AdHelper: Loading Interstitial Ad (Attempt ${_loadRetryCount + 1})...",
    );

    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint("AdHelper: Interstitial Ad loaded successfully.");
          _interstitialAd = ad;
          _isInterstitialAdLoading = false;
          _loadRetryCount = 0;
          onAdLoaded?.call();
        },
        onAdFailedToLoad: (err) {
          debugPrint(
            "AdHelper: Interstitial Ad failed to load: ${err.message}",
          );
          _isInterstitialAdLoading = false;
          _interstitialAd = null;

          // Exponential backoff retry
          if (_loadRetryCount < 3) {
            _loadRetryCount++;
            int delay = _loadRetryCount * 10; // 10s, 20s, 30s
            debugPrint("AdHelper: Retrying in $delay seconds...");
            Future.delayed(
              Duration(seconds: delay),
              () => loadInterstitialAd(),
            );
          }

          onAdFailed?.call();
        },
      ),
    );
  }

  static void showInterstitialAd(void Function() onAdDismissed) {
    _clickCount++;
    debugPrint(
      "AdHelper: showInterstitialAd requested. Total Actions: $_clickCount",
    );
    
    // Request app review in the background on action completion
    ReviewHelper.incrementActionAndRequestReview();

    bool shouldShowAd = false;

    // Policy Check: Clicks and Interval Seconds
    if (_clickCount >= _adIntervalClicks) {
      if (_lastAdTime == null) {
        shouldShowAd = true;
        debugPrint("AdHelper: First ad session.");
      } else {
        final elapsed = DateTime.now().difference(_lastAdTime!).inSeconds;
        debugPrint("AdHelper: Time since last ad: $elapsed seconds.");
        if (elapsed >= _adIntervalSeconds) {
          shouldShowAd = true;
        }
      }
    }

    if (!shouldShowAd) {
      debugPrint(
        "AdHelper: Policy - Skipping ad. Reason: Either interval not reached or clicks count too low.",
      );
      onAdDismissed();
      return;
    }

    if (_interstitialAd == null) {
      debugPrint(
        "AdHelper: Ad not available. Action continues, ad loading in background.",
      );
      onAdDismissed();
      unawaited(loadInterstitialAd());
      return;
    }

    debugPrint("AdHelper: Ad is ready. Showing now.");
    _clickCount = 0;
    _lastAdTime = DateTime.now();

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        debugPrint("AdHelper: Ad dismissed by user.");
        ad.dispose();
        _interstitialAd = null;
        unawaited(loadInterstitialAd()); // Load next ad immediately
        onAdDismissed();
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        debugPrint("AdHelper: Ad failed to show: ${err.message}");
        ad.dispose();
        _interstitialAd = null;
        unawaited(loadInterstitialAd());
        onAdDismissed();
      },
    );

    try {
      _interstitialAd!.show();
    } catch (e) {
      debugPrint("AdHelper: Critical error showing ad: $e");
      _interstitialAd?.dispose();
      _interstitialAd = null;
      unawaited(loadInterstitialAd());
      onAdDismissed();
    }
  }
}
