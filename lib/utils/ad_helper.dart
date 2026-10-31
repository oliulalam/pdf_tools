import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:pdf_toolkit/utils/review_helper.dart';

class AdHelper {
  static const String _prodBannerHome = 'REPLACE_ME';
  static const String _prodBannerRecent = 'REPLACE_ME';
  static const String _prodBannerTools = 'REPLACE_ME';
  static const String _prodInterstitial = 'REPLACE_ME';

  static String get bannerHomeAdUnitId {
    if (Platform.isAndroid) {
      return kDebugMode ? 'ca-app-pub-3940256099942544/6300978111' : _prodBannerHome;
    }
    throw UnsupportedError('Unsupported platform');
  }

  static String get bannerRecentAdUnitId {
    if (Platform.isAndroid) {
      return kDebugMode ? 'ca-app-pub-3940256099942544/6300978111' : _prodBannerRecent;
    }
    throw UnsupportedError('Unsupported platform');
  }

  static String get bannerToolsAdUnitId {
    if (Platform.isAndroid) {
      return kDebugMode ? 'ca-app-pub-3940256099942544/6300978111' : _prodBannerTools;
    }
    throw UnsupportedError('Unsupported platform');
  }

  // Alias to keep existing code compiling
  static String get bannerAdUnitId => bannerToolsAdUnitId;

  static String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return kDebugMode ? 'ca-app-pub-3940256099942544/1033173712' : _prodInterstitial;
    }
    throw UnsupportedError('Unsupported platform');
  }

  static bool isFullScreenShowing = false;

  static InterstitialAd? _interstitialAd;
  static bool _isInterstitialAdLoading = false;
  static DateTime? _loadingStartTime;
  static int _loadRetryCount = 0;
  static DateTime? _interstitialLoadTime;

  static DateTime? _lastAdTime;
  static const int _adIntervalSeconds = 60; // 60 seconds cooldown gap

  // ValueNotifier to trigger banner ads when consent is obtained
  static final ValueNotifier<bool> adsReady = ValueNotifier(false);

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

  static Future<void> _initializeAdsIfReady() async {
    final canRequest = await ConsentInformation.instance.canRequestAds();
    if (canRequest || kDebugMode) {
      if (kDebugMode) {
        final requestConfiguration = RequestConfiguration(
          testDeviceIds: ["C60E55548632D3DA3550DAC043F61B4C"],
        );
        MobileAds.instance.updateRequestConfiguration(requestConfiguration);
      }
      await MobileAds.instance.initialize();
      adsReady.value = true;
      unawaited(loadInterstitialAd());
    }
  }

  static Future<void> preLoadAds() async {
    debugPrint("AdHelper: Pre-loading Interstitial Ad...");
    await loadInterstitialAd();
  }

  static Future<void> loadInterstitialAd({
    VoidCallback? onAdLoaded,
    VoidCallback? onAdFailed,
  }) async {
    final canRequest = await ConsentInformation.instance.canRequestAds();
    if ((!canRequest && !kDebugMode) || (!kDebugMode && interstitialAdUnitId == 'REPLACE_ME')) {
      onAdFailed?.call();
      return;
    }

    if (_interstitialAd != null) {
      debugPrint("AdHelper: Interstitial Ad already loaded.");
      onAdLoaded?.call();
      return;
    }

    // Reset lock if previous load attempt got stuck for over 10 seconds
    if (_isInterstitialAdLoading && _loadingStartTime != null) {
      if (DateTime.now().difference(_loadingStartTime!).inSeconds > 10) {
        debugPrint("AdHelper: Previous load attempt timed out. Resetting lock.");
        _isInterstitialAdLoading = false;
      }
    }

    if (_isInterstitialAdLoading) {
      debugPrint("AdHelper: Ad is currently loading, waiting...");
      int waitMs = 0;
      while (_isInterstitialAdLoading && waitMs < 6000) {
        await Future.delayed(const Duration(milliseconds: 200));
        waitMs += 200;
      }
      if (_interstitialAd != null) {
        onAdLoaded?.call();
      } else {
        onAdFailed?.call();
      }
      return;
    }

    _isInterstitialAdLoading = true;
    _loadingStartTime = DateTime.now();
    debugPrint(
      "AdHelper: Loading Interstitial Ad (Attempt ${_loadRetryCount + 1})...",
    );

    final completer = Completer<void>();

    try {
      InterstitialAd.load(
        adUnitId: interstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            debugPrint("AdHelper: Interstitial Ad loaded successfully.");
            _interstitialAd = ad;
            _interstitialLoadTime = DateTime.now();
            _isInterstitialAdLoading = false;
            _loadingStartTime = null;
            _loadRetryCount = 0;
            onAdLoaded?.call();
            if (!completer.isCompleted) completer.complete();
          },
          onAdFailedToLoad: (err) {
            debugPrint(
              "AdHelper: Interstitial Ad failed to load: ${err.message}",
            );
            _isInterstitialAdLoading = false;
            _loadingStartTime = null;
            _interstitialAd = null;

            // Exponential backoff retry: 10s, 30s, 60s, then 5m
            _loadRetryCount++;
            int delay = 10;
            if (_loadRetryCount == 2) {
              delay = 30;
            } else if (_loadRetryCount == 3) {
              delay = 60;
            } else if (_loadRetryCount > 3) {
              delay = 300;
            }
            
            debugPrint("AdHelper: Retrying in $delay seconds...");
            Future.delayed(
              Duration(seconds: delay),
              () => loadInterstitialAd(),
            );

            onAdFailed?.call();
            if (!completer.isCompleted) completer.complete();
          },
        ),
      );
    } catch (e) {
      debugPrint("AdHelper: Exception in InterstitialAd.load: $e");
      _isInterstitialAdLoading = false;
      _loadingStartTime = null;
      if (!completer.isCompleted) completer.complete();
    }

    await completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        debugPrint("AdHelper: InterstitialAd.load timeout.");
        _isInterstitialAdLoading = false;
        _loadingStartTime = null;
      },
    );
  }

  static Future<void> showInterstitialAd(void Function() onAdDismissed) async {
    debugPrint("AdHelper: showInterstitialAd requested.");

    bool shouldShowAd = false;

    if (kDebugMode) {
      // In debug mode, allow testing the ad immediately on every action
      shouldShowAd = true;
      debugPrint("AdHelper: Debug mode - Allowing interstitial ad for testing.");
    } else {
      // 60-second cooldown check in release mode
      if (_lastAdTime == null) {
        shouldShowAd = true;
        debugPrint("AdHelper: First ad session.");
      } else if (DateTime.now().difference(_lastAdTime!).inSeconds >= _adIntervalSeconds) {
        shouldShowAd = true;
      } else {
        shouldShowAd = false;
      }
    }

    if (!shouldShowAd) {
      debugPrint(
        "AdHelper: Cooldown active - Skipping ad. Action continues.",
      );
      // Request app review ONLY if ad is NOT shown
      ReviewHelper.incrementActionAndRequestReview();
      onAdDismissed();
      return;
    }

    // Check expiry
    if (_interstitialAd != null && _interstitialLoadTime != null) {
      if (DateTime.now().difference(_interstitialLoadTime!).inMinutes > 55) {
        debugPrint("AdHelper: Ad expired, discarding.");
        _interstitialAd!.dispose();
        _interstitialAd = null;
      }
    }

    // If ad is not preloaded, attempt to load it on-demand now!
    if (_interstitialAd == null) {
      debugPrint("AdHelper: Ad not preloaded yet. Attempting to load on-demand now...");
      await loadInterstitialAd();
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
    _lastAdTime = DateTime.now();

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        isFullScreenShowing = true;
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint("AdHelper: Ad dismissed by user.");
        isFullScreenShowing = false;
        ad.dispose();
        _interstitialAd = null;
        unawaited(loadInterstitialAd()); // Load next ad immediately
        onAdDismissed();
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        debugPrint("AdHelper: Ad failed to show: ${err.message}");
        isFullScreenShowing = false;
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
