
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_manager.dart';

class BannerAdWidget extends StatefulWidget {
  final AdSize adSize;
  final EdgeInsets? margin;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;

  const BannerAdWidget({
    super.key,
    this.adSize = AdSize.banner,
    this.margin,
    this.backgroundColor,
    this.borderRadius,
  });

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    _bannerAd = BannerAd(
      adUnitId: AdManager.bannerAdUnitId,
      request: const AdRequest(),
      size: widget.adSize,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isAdLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          if (kDebugMode) {
            print('Banner ad failed to load: $error');
          }
          ad.dispose();
        },
      ),
    );

    _bannerAd?.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    Widget adWidget = Container(
      alignment: Alignment.center,
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: widget.borderRadius,
      ),
      child: AdWidget(ad: _bannerAd!),
    );

    if (widget.margin != null) {
      adWidget = Container(
        margin: widget.margin,
        child: adWidget,
      );
    }

    return adWidget;
  }
}