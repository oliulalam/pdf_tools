import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../utils/ad_helper.dart';

enum AdPlacement { home, recent, tools }

class BannerAdWidget extends StatefulWidget {
  final AdPlacement placement;
  
  const BannerAdWidget({super.key, required this.placement});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  AdSize? _adSize;
  bool _isLoading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_adSize == null && !_isLoading && AdHelper.adsReady.value) {
      _loadAd();
    }
  }

  @override
  void initState() {
    super.initState();
    AdHelper.adsReady.addListener(_onAdsReadyChanged);
  }

  void _onAdsReadyChanged() {
    if (AdHelper.adsReady.value && _bannerAd == null && !_isLoading && mounted) {
      _loadAd();
    }
  }

  String get _adUnitId {
    switch (widget.placement) {
      case AdPlacement.home:
        return AdHelper.bannerHomeAdUnitId;
      case AdPlacement.recent:
        return AdHelper.bannerRecentAdUnitId;
      case AdPlacement.tools:
        return AdHelper.bannerToolsAdUnitId;
    }
  }

  Future<void> _loadAd() async {
    _isLoading = true;
    
    // Get anchored adaptive banner size
    final screenWidth = MediaQuery.of(context).size.width.truncate();
    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(screenWidth);
    
    if (!mounted) return;
    
    _adSize = size ?? AdSize.banner;

    _bannerAd = BannerAd(
      adUnitId: _adUnitId,
      size: _adSize!,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _bannerAd = null;
          _isLoading = false;
          debugPrint('BannerAd failed to load: $error');
        },
      ),
    );
    if (mounted) {
      _bannerAd!.load();
    }
  }

  @override
  void dispose() {
    AdHelper.adsReady.removeListener(_onAdsReadyChanged);
    _bannerAd?.dispose();
    _bannerAd = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_adSize == null) {
      return const SizedBox.shrink();
    }
    
    if (!_isLoaded || _bannerAd == null) {
      // Reserve exact height so layout doesn't jump
      return SizedBox(
        width: _adSize!.width.toDouble(),
        height: _adSize!.height.toDouble() + 20, // height + ad label space
      );
    }

    return Container(
      width: double.infinity,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8), // Provide minimum spacing from interactive elements
          Text(
            "Advertisement",
            style: TextStyle(
              color: Theme.of(context).hintColor.withAlpha(150),
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: _bannerAd!.size.width.toDouble(),
            height: _bannerAd!.size.height.toDouble(),
            child: AdWidget(ad: _bannerAd!),
          ),
          const SizedBox(height: 8), // Provide minimum spacing from interactive elements
        ],
      ),
    );
  }
}
