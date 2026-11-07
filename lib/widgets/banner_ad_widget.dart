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
  double? _lastWidth;

  @override
  void initState() {
    super.initState();
    AdHelper.adsReady.addListener(_onAdsReadyChanged);
  }

  void _onAdsReadyChanged() {
    if (AdHelper.adsReady.value && _bannerAd == null && !_isLoading && mounted) {
      if (_lastWidth != null) {
        _loadAd(_lastWidth!);
      }
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

  Future<void> _loadAd(double width) async {
    _isLoading = true;
    _lastWidth = width;

    final int adWidth = width.clamp(280.0, 1200.0).truncate();
    final Orientation orientation = MediaQuery.of(context).orientation;
    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSizeWithOrientation(orientation, adWidth);

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;

        if (_bannerAd == null && !_isLoading && AdHelper.adsReady.value && availableWidth > 0) {
          _loadAd(availableWidth);
        }

        if (_adSize == null) {
          return const SizedBox.shrink();
        }

        if (!_isLoaded || _bannerAd == null) {
          return SafeArea(
            top: false,
            bottom: true,
            minimum: const EdgeInsets.only(bottom: 8.0),
            child: SizedBox(
              width: double.infinity,
              height: _adSize!.height.toDouble() + 24,
            ),
          );
        }

        return SafeArea(
          top: false,
          bottom: true,
          minimum: const EdgeInsets.only(bottom: 8.0),
          child: Container(
            width: double.infinity,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Advertisement",
                  style: TextStyle(
                    color: Theme.of(context).hintColor.withAlpha(180),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: SizedBox(
                    width: _bannerAd!.size.width.toDouble(),
                    height: _bannerAd!.size.height.toDouble(),
                    child: AdWidget(ad: _bannerAd!),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
