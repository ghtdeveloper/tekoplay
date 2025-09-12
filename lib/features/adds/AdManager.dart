
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdManager {
  // IDs de anuncios - cambia estos por los reales en producción
  static const String bannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static const String interstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';

  // Inicializar AdMob (llamar en main.dart)
  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
  }
}