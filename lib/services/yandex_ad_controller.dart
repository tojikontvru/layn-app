import 'package:flutter/material.dart';
import 'package:yandex_mobileads/mobile_ads.dart' as yandex;

import '../services/ad_service.dart';

/// Контроллер полноэкранной (видео) рекламы Яндекса на плеере.
/// Показывает интерстициальную рекламу с кнопкой «пропустить».
class YandexAdController {
  YandexAdController._();

  static YandexAdController? _instance;

  bool _isShowing = false;

  /// Единый экземпляр.
  static YandexAdController get instance => _instance ??= YandexAdController._();

  /// Загружает и показывает полноэкранную видео-рекламу.
  /// Ничего не делает, если реклама уже показывается в данный момент.
  Future<void> showInterstitial({required AdService s}) async {
    if (_isShowing) return;
    final unitId = s.interstitialUnitId;
    if (unitId.isEmpty) return;

    _isShowing = true;
    try {
      final loader = await yandex.InterstitialAdLoader.create(
        onAdLoaded: (ad) {
          _showLoadedAd(ad);
        },
        onAdFailedToLoad: (error) {
          debugPrint('YandexAdController: load failed: ${error.description}');
        },
      );
      await loader.loadAd(
        adRequestConfiguration: yandex.AdRequestConfiguration(adUnitId: unitId),
      );
    } catch (e) {
      debugPrint('YandexAdController: interstitial error: $e');
      _isShowing = false;
    }
  }

  void _showLoadedAd(yandex.InterstitialAd ad) {
    ad.setAdEventListener(
      eventListener: yandex.InterstitialAdEventListener(
        onAdShown: () {},
        onAdFailedToShow: (error) {
          _isShowing = false;
        },
        onAdDismissed: () {
          _isShowing = false;
        },
      ),
    );
    ad.show().then((_) {}).catchError((e) {
      _isShowing = false;
    });

    // Страховка от «зависания» флага при редких сбоях обратных вызовов.
    Future.delayed(const Duration(seconds: 4), () {
      _isShowing = false;
    });
  }
}