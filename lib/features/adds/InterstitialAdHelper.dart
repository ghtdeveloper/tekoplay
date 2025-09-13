import 'dart:ui';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'AdManager.dart';

class InterstitialAdHelper {
  InterstitialAd? _interstitialAd;
  bool _isAdReady = false;
  int _actionCounter = 0;
  final int _showFrequency;

  InterstitialAdHelper({int showFrequency = 3})
    : _showFrequency = showFrequency {
    _loadAd();
  }

  Future<void> _loadAd() async {
    await InterstitialAd.load(
      adUnitId: AdManager.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
          _isAdReady = true;
          ad.setImmersiveMode(true);
        },
        onAdFailedToLoad: (LoadAdError error) {
          print('InterstitialAd failed to load: $error');
          _isAdReady = false;
        },
      ),
    );
  }

  // Mostrar anuncio basado en frecuencia
  void showAdIfReady({VoidCallback? onComplete}) {
    _actionCounter++;

    if (_actionCounter % _showFrequency == 0 && _isAdReady) {
      _showAd(onComplete: onComplete);
    } else {
      onComplete?.call();
    }
  }

  // Forzar mostrar anuncio
  void forceShowAd({VoidCallback? onComplete}) {
    if (_isAdReady) {
      _showAd(onComplete: onComplete);
    } else {
      onComplete?.call();
    }
  }

  void _showAd({VoidCallback? onComplete}) {
    if (_interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (InterstitialAd ad) {
          print('Interstitial ad showed.');
        },
        onAdDismissedFullScreenContent: (InterstitialAd ad) {
          print('Interstitial ad dismissed.');
          ad.dispose();
          _loadAd();
          onComplete?.call();
        },
        onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
          print('Interstitial ad failed to show: $error');
          ad.dispose();
          _loadAd();
          onComplete?.call();
        },
      );
      _interstitialAd!.show();
      _isAdReady = false;
    }
  }

  void dispose() {
    _interstitialAd?.dispose();
  }
}
