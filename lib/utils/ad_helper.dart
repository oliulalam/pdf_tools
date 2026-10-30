import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf_toolkit/utils/review_helper.dart';

class AdHelper {
  static const String _prodBannerHome = 'REPLACE_ME';
  static const String _prodBannerRecent = 'REPLACE_ME';
  static const String _prodBannerTools = 'REPLACE_ME';
  static const String _prodInterstitial = 'REPLACE_ME';
  static const String _prodRewarded = 'REPLACE_ME';
  static const String _prodAppOpen = 'REPLACE_ME';

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

  static String get rewardedAdUnitId {
    if (Platform.isAndroid) {
      return kDebugMode ? 'ca-app-pub-3940256099942544/5224354917' : _prodRewarded;
    }
    throw UnsupportedError('Unsupported platform');
  }

  static String get appOpenAdUnitId {
    if (Platform.isAndroid) {
      return kDebugMode ? 'ca-app-pub-3940256099942544/9257395921' : _prodAppOpen;
    }
    throw UnsupportedError('Unsupported platform');
  }

  static AppOpenAd? _appOpenAd;
  static bool _isAppOpenAdLoading = false;
  static DateTime? _appOpenLoadTime;
  static bool isFullScreenShowing = false;

  static InterstitialAd? _interstitialAd;
  static bool _isInterstitialAdLoading = false;
  static int _loadRetryCount = 0;
  static DateTime? _interstitialLoadTime;

  static RewardedAd? _rewardedAd;
  static bool _isRewardedAdLoading = false;
  static DateTime? _rewardedLoadTime;

  static int _clickCount = 0;
  static DateTime? _lastAdTime;
  static const int _adIntervalClicks = 3; 
  static const int _adIntervalSeconds = 180; // 3 minutes gap

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
    if (canRequest) {
      if (kDebugMode) {
        // Register test device IDs here if testing on physical device
        final requestConfiguration = RequestConfiguration(testDeviceIds: []); // paste your device id here
        MobileAds.instance.updateRequestConfiguration(requestConfiguration);
      }
      await MobileAds.instance.initialize();
      adsReady.value = true;
      unawaited(loadInterstitialAd());
      unawaited(loadRewardedAd());
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
    if (!canRequest || (!kDebugMode && interstitialAdUnitId == 'REPLACE_ME')) {
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
          _interstitialLoadTime = DateTime.now();
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
        },
      ),
    );
  }

  static void showInterstitialAd(void Function() onAdDismissed) {
    _clickCount++;
    debugPrint(
      "AdHelper: showInterstitialAd requested. Total Actions: $_clickCount",
    );

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

  static Future<void> loadRewardedAd() async {
    final canRequest = await ConsentInformation.instance.canRequestAds();
    if (!canRequest || (!kDebugMode && rewardedAdUnitId == 'REPLACE_ME')) {
      return;
    }

    if (_isRewardedAdLoading || _rewardedAd != null) {
      return;
    }

    _isRewardedAdLoading = true;
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint("AdHelper: Rewarded Ad loaded successfully.");
          _rewardedAd = ad;
          _rewardedLoadTime = DateTime.now();
          _isRewardedAdLoading = false;
        },
        onAdFailedToLoad: (err) {
          debugPrint("AdHelper: Rewarded Ad failed to load: ${err.message}");
          _isRewardedAdLoading = false;
          _rewardedAd = null;
        },
      ),
    );
  }

  static void showRewardedAd({
    required VoidCallback onReward,
    VoidCallback? onUnavailable,
  }) {
    // Check expiry (55 minutes)
    if (_rewardedAd != null && _rewardedLoadTime != null) {
      if (DateTime.now().difference(_rewardedLoadTime!).inMinutes > 55) {
        _rewardedAd!.dispose();
        _rewardedAd = null;
      }
    }

    if (_rewardedAd == null) {
      onUnavailable?.call();
      unawaited(loadRewardedAd());
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        isFullScreenShowing = true;
      },
      onAdDismissedFullScreenContent: (ad) {
        isFullScreenShowing = false;
        ad.dispose();
        _rewardedAd = null;
        unawaited(loadRewardedAd());
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        isFullScreenShowing = false;
        ad.dispose();
        _rewardedAd = null;
        onUnavailable?.call();
        unawaited(loadRewardedAd());
      },
    );

    _rewardedAd!.show(onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
      onReward();
    });
    _rewardedAd = null;
  }

  static Future<void> loadAppOpenAd() async {
    final canRequest = await ConsentInformation.instance.canRequestAds();
    if (!canRequest || (!kDebugMode && appOpenAdUnitId == 'REPLACE_ME')) {
      return;
    }

    if (_isAppOpenAdLoading || _appOpenAd != null) {
      return;
    }

    _isAppOpenAdLoading = true;
    AppOpenAd.load(
      adUnitId: appOpenAdUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint("AdHelper: App Open Ad loaded successfully.");
          _appOpenAd = ad;
          _appOpenLoadTime = DateTime.now();
          _isAppOpenAdLoading = false;
        },
        onAdFailedToLoad: (error) {
          debugPrint("AdHelper: App Open Ad failed to load: ${error.message}");
          _isAppOpenAdLoading = false;
          _appOpenAd = null;
        },
      ),
    );
  }

  static Future<void> showAppOpenAdIfAvailable() async {
    if (isFullScreenShowing) {
      debugPrint("AdHelper: App Open Ad skipped because another full screen UI is active.");
      return;
    }

    final canRequest = await ConsentInformation.instance.canRequestAds();
    if (!canRequest) return;

    // Check expiry (4 hours)
    if (_appOpenAd != null && _appOpenLoadTime != null) {
      if (DateTime.now().difference(_appOpenLoadTime!).inHours >= 4) {
        _appOpenAd!.dispose();
        _appOpenAd = null;
      }
    }

    if (_appOpenAd == null) {
      unawaited(loadAppOpenAd());
      return;
    }

    // Rate limiting: at most once per 4 hours and at most 3 per day
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final lastShowMillis = prefs.getInt('app_open_last_show_time') ?? 0;
    final todayCount = prefs.getInt('app_open_today_count') ?? 0;
    final todayDate = prefs.getString('app_open_today_date') ?? '';

    final todayStr = "${now.year}-${now.month}-${now.day}";
    int currentDailyCount = (todayDate == todayStr) ? todayCount : 0;

    if (now.millisecondsSinceEpoch - lastShowMillis < 4 * 3600 * 1000) {
      debugPrint("AdHelper: App Open Ad rate limited (less than 4 hours).");
      return;
    }

    if (currentDailyCount >= 3) {
      debugPrint("AdHelper: App Open Ad rate limited (daily limit 3 reached).");
      return;
    }

    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        isFullScreenShowing = true;
      },
      onAdDismissedFullScreenContent: (ad) {
        isFullScreenShowing = false;
        ad.dispose();
        _appOpenAd = null;
        unawaited(loadAppOpenAd());
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        isFullScreenShowing = false;
        ad.dispose();
        _appOpenAd = null;
        unawaited(loadAppOpenAd());
      },
    );

    await prefs.setInt('app_open_last_show_time', now.millisecondsSinceEpoch);
    await prefs.setString('app_open_today_date', todayStr);
    await prefs.setInt('app_open_today_count', currentDailyCount + 1);

    _appOpenAd!.show();
    _appOpenAd = null;
  }
}
