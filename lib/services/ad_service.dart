import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:yandex_mobileads/mobile_ads.dart' as yandex;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AdService extends ChangeNotifier {
  static const _baseUrl = 'https://layn.su';

  // Yandex config
  String? _yandexAppId;
  String? _yandexBannerUnitId;
  String? _yandexInterstitialUnitId;
  String? _yandexRewardedUnitId;
  bool _yandexActive = false;
  bool _yandexTestMode = false;

  // Места показа (управляются из админки)
  int _feedInterval = 6; // каждые N постов в ленте
  bool _feedEnabled = true; // реклама в ленте главной
  bool _playerEnabled = true; // реклама на видеоплеере
  int _playerSecond = 0; // секунда видео, на которой показать полноэкранную рекламу
  bool _pageEnabled = true; // реклама на странице видео (под каналом)

  bool _initialized = false;

  // Getters
  String? get yandexAppId => _yandexAppId;
  String? get yandexBannerUnitId => _yandexBannerUnitId;
  String? get yandexInterstitialUnitId => _yandexInterstitialUnitId;
  String? get yandexRewardedUnitId => _yandexRewardedUnitId;
  bool get yandexActive => _yandexActive;
  int get feedInterval => _feedInterval;
  bool get feedEnabled => _feedEnabled;
  bool get playerEnabled => _playerEnabled;
  int get playerSecond => _playerSecond;
  bool get pageEnabled => _pageEnabled;

  /// Короткий алиас для banner unit id (используется YandexBanner).
  /// В тестовом режиме всегда подставляется официальный демо-ID Яндекса,
  /// чтобы баннер гарантированно загружался без регистрации блока.
  String get bannerUnitId {
    if (_yandexTestMode) return 'demo-banner-yandex';
    return _yandexBannerUnitId ?? '';
  }

  /// Unit ID для полноэкранной (видео) рекламы на плеере.
  /// В тестовом режиме — официальный демо-ID Яндекса (пропускаемая видеореклама).
  String get interstitialUnitId {
    if (_yandexTestMode) return 'demo-interstitial-yandex';
    return _yandexInterstitialUnitId ?? '';
  }

  bool get isInitialized => _initialized;

  static final AdService _instance = AdService._();
  factory AdService() => _instance;
  AdService._();

  Future<void> init() async {
    if (_initialized) return;
    await _loadConfig();
    await _initYandex();
    _initialized = true;
    notifyListeners();
  }

  Future<void> _loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      final response = await http.get(
        Uri.parse('$_baseUrl/api/v1/ad-networks'),
        headers: {
          'Accept': 'application/json',
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          final networks = data['data'] as Map<String, dynamic>;

          // Yandex
          if (networks['yandex'] != null) {
            final y = networks['yandex'] as Map<String, dynamic>;
            _yandexAppId = y['app_id']?.toString();
            _yandexBannerUnitId = y['banner_unit_id']?.toString();
            _yandexInterstitialUnitId = y['interstitial_unit_id']?.toString();
            _yandexRewardedUnitId = y['rewarded_unit_id']?.toString();
            _yandexActive = y['is_active'] == true || y['is_active'] == 1;
            _yandexTestMode = y['test_mode'] == true || y['test_mode'] == 1;
            // Места показа (из админки)
            _feedInterval = int.tryParse('${y['feed_interval'] ?? 6}') ?? 6;
            _feedEnabled = y['feed_enabled'] != false;
            _playerEnabled = y['player_enabled'] != false;
            _playerSecond = int.tryParse('${y['player_second'] ?? 0}') ?? 0;
            _pageEnabled = y['page_enabled'] != false;
          }
        }
      }
    } catch (e) {
      debugPrint('AdService: failed to load config: $e');
    }
  }

  // ─── Yandex Ads ────────────────────────────────────────────

  Future<void> _initYandex() async {
    if (!_yandexActive) return;

    try {
      await yandex.MobileAds.initialize();
      debugPrint('AdService: Yandex Mobile Ads initialized');
    } catch (e) {
      debugPrint('AdService: Yandex init failed: $e');
    }
  }

  /// Show Yandex interstitial ad
  Future<void> showYandexInterstitial() async {
    if (!_yandexActive || _yandexInterstitialUnitId == null) return;
    if (_yandexTestMode) {
      debugPrint('AdService: Yandex test mode — skipping interstitial');
      return;
    }

    late final yandex.InterstitialAdLoader loader;
    try {
      loader = await yandex.InterstitialAdLoader.create(
        onAdLoaded: (yandex.InterstitialAd ad) {
          debugPrint('Yandex interstitial loaded');
          ad.setAdEventListener(
            eventListener: yandex.InterstitialAdEventListener(
              onAdShown: () => debugPrint('Yandex interstitial shown'),
              onAdFailedToShow: (error) =>
                  debugPrint('Yandex interstitial show failed: $error'),
              onAdDismissed: () {
                debugPrint('Yandex interstitial dismissed');
                ad.destroy();
              },
              onAdClicked: () => debugPrint('Yandex interstitial clicked'),
            ),
          );
          ad.show();
        },
        onAdFailedToLoad: (error) {
          debugPrint('Yandex interstitial load failed: ${error.description}');
        },
      );

      await loader.loadAd(
        adRequestConfiguration: yandex.AdRequestConfiguration(
          adUnitId: _yandexInterstitialUnitId!,
        ),
      );
    } catch (e) {
      debugPrint('Yandex interstitial error: $e');
    }
  }
}
