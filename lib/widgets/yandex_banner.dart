import 'package:flutter/material.dart';
import 'package:yandex_mobileads/mobile_ads.dart' as yandex;

import '../services/ad_service.dart';

/// Место показа рекламного баннера.
enum AdPlacement {
  /// В ленте видео на главной (обычный широкий блок).
  feed,

  /// В ленте видео на главной (большой «видео»-блок, чередуется с feed).
  feedLarge,

  /// На видеоплеере.
  player,

  /// На странице просмотра видео (под каналом, между похожими видео).
  page,
}

/// Рекламный баннер Яндекса для вставки в ленту / плеер / страницу видео.
///
/// - Если реклама отключена в админке (feed_enabled/player_enabled/page_enabled
///   или is_active=false) — виджет ничего не рисует (SizedBox.shrink).
/// - Пока баннер загружается — занимает своё место с высотой 0 (не прыгает список).
/// - При ошибке загрузки — просто пустой виджет.
class YandexBanner extends StatefulWidget {
  const YandexBanner({
    super.key,
    this.placement = AdPlacement.feed,
    this.width,
    this.height = 50,
  });

  /// Куда вставляется баннер: feed / player / page.
  final AdPlacement placement;

  /// Ширина баннера (по умолчанию — ширина экрана).
  final double? width;

  /// Высота баннера.
  final double height;

  @override
  State<YandexBanner> createState() => _YandexBannerState();
}

class _YandexBannerState extends State<YandexBanner> {
  yandex.BannerAd? _banner;
  bool _loaded = false;
  bool _failed = false;

  bool get _enabled {
    final s = AdService();
    if (!s.yandexActive) return false;
    return switch (widget.placement) {
      AdPlacement.feed => s.feedEnabled,
      AdPlacement.feedLarge => s.feedEnabled,
      AdPlacement.player => s.playerEnabled,
      AdPlacement.page => s.pageEnabled,
    };
  }

  String get _unitId => AdService().bannerUnitId;

  @override
  void initState() {
    super.initState();
    if (_enabled && _unitId.isNotEmpty) {
      _load();
    } else {
      _failed = true;
    }
  }

  Future<void> _load() async {
    try {
      final width = (widget.width ?? MediaQuery.of(context).size.width)
          .clamp(320.0, 480.0)
          .round();
      final banner = yandex.BannerAd(
        adUnitId: _unitId,
        adSize: yandex.BannerAdSize.inline(
          width: width,
          maxHeight: widget.height.round(),
        ),
      );
      await banner.loadAd();
      if (!mounted) {
        await banner.destroy();
        return;
      }
      setState(() {
        _banner = banner;
        _loaded = true;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _failed = true);
      }
    }
  }

  @override
  void dispose() {
    _banner?.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled || _failed || !_loaded || _banner == null) {
      // Не занимаем место, если реклама не показывается
      return const SizedBox.shrink();
    }
    return yandex.AdWidget(bannerAd: _banner!);
  }
}
