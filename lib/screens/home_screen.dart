import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/ad_service.dart';
import '../widgets/video_card.dart';
import '../widgets/ad_card.dart';
import '../widgets/yandex_banner.dart';
import 'video_screen.dart';
import 'notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  final ValueNotifier<bool>? uiVisible;

  const HomeScreen({super.key, this.uiVisible});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _videos = <Video>[];
  final _ads = <Ad>[];
  final _categories = <Category>[];
  final _scrollCtrl = ScrollController();
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  int _lastPage = 1;
  String? _selectedCategory;

  // Scroll hiding
  bool _categoryVisible = true;
  double _lastScrollOffset = 0;

  // Unread posts counter for the bell badge
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAll();
    _loadUnreadCount();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ═══ Scroll hide/show UI ═══
  bool _uiHiddenByScroll = false;
  Timer? _showTimer;

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final current = _scrollCtrl.position.pixels;
    final diff = current - _lastScrollOffset;
    _lastScrollOffset = current;

    // Cancel pending show timer
    _showTimer?.cancel();

    // Scroll DOWN (content goes up) → hide
    if (diff > 8 && current > 80) {
      if (!_uiHiddenByScroll) {
        _uiHiddenByScroll = true;
        widget.uiVisible?.value = false;
        if (mounted) setState(() => _categoryVisible = false);
      }
      return;
    }

    // Scroll UP (content comes down) → show immediately
    if (diff < -8) {
      if (_uiHiddenByScroll) {
        _uiHiddenByScroll = false;
        widget.uiVisible?.value = true;
        if (mounted) setState(() => _categoryVisible = true);
      }
    }

    // Load more
    if (current >= _scrollCtrl.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  /// Smooth show after scroll stops (debounced 150ms)
  void _onScrollEnd() {
    _showTimer?.cancel();
    _showTimer = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      if (_uiHiddenByScroll) {
        _uiHiddenByScroll = false;
        widget.uiVisible?.value = true;
        setState(() => _categoryVisible = true);
      }
    });
  }

  Future<void> _loadAll() async {
    // Parallel loading: categories + videos + ads all at once
    await Future.wait([
      _loadCategories(),
      _loadVideos(),
    ]);
  }

  Future<void> _loadCategories() async {
    final cats = await ApiService.instance.categories();
    if (mounted) {
      if (cats.isEmpty) {
        setState(() => _categories.addAll([
          Category(id: 1, name: 'Музыка', slug: 'mus8c'),
          Category(id: 2, name: 'Фильмы', slug: 'movie'),
          Category(id: 3, name: 'Сериалы', slug: 'series'),
          Category(id: 4, name: 'Развлечение', slug: 'entertainment'),
        ]));
      } else {
        setState(() => _categories.addAll(cats));
      }
    }
  }

  Future<void> _loadVideos() async {
    setState(() { _loading = true; _error = null; _page = 1; });
    try {
      final d = await ApiService.instance.home(page: 1, category: _selectedCategory);
      final videosRaw = (d['data']?['videos'] as List? ?? []);
      final list = videosRaw
          .map((e) => Video.fromJson(e as Map<String, dynamic>))
          .toList();

      final meta = d['data'] ?? {};
      setState(() {
        _videos.clear();
        _videos.addAll(list);
        _lastPage = meta['last_page'] ?? 1;
        _loading = false;
      });

      // Load ads in background after videos are shown
      _loadAds();
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _loadAds() async {
    try {
      final allAds = await ApiService.instance.ads();
      final feedAds = allAds.where((a) => a.type == 'feed').toList();
      if (mounted) {
        setState(() {
          _ads..clear()..addAll(feedAds);
        });
      }
    } catch (_) {}
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _page >= _lastPage) return;
    setState(() => _loadingMore = true);
    try {
      final nextPage = _page + 1;
      final d = await ApiService.instance.home(page: nextPage, category: _selectedCategory);
      final videosRaw = (d['data']?['videos'] as List? ?? []);
      final list = videosRaw
          .map((e) => Video.fromJson(e as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _videos.addAll(list);
          _page = nextPage;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onCategorySelected(String? slug) {
    if (_selectedCategory == slug) return;
    setState(() => _selectedCategory = slug);
    _loadVideos();
  }

  /// Загружает количество непрочитанных постов для бейджа на колокольчике.
  /// Прочитанным считается пост, если его id уже виден в SharedPreferences
  /// (lastSeenPostId обновляется при открытии экрана уведомлений).
  Future<void> _loadUnreadCount() async {
    try {
      final items = await ApiService.instance.notifications();
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      final lastSeen = prefs.getInt('lastSeenPostId') ?? 0;
      final unread = items.where((n) => n.id > lastSeen).length;
      if (mounted && unread != _unreadCount) {
        setState(() => _unreadCount = unread);
      }
    } catch (_) {}
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    // После возврата — пересчитать счётчик (внутри экрана всё помечено прочитанным)
    _loadUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
        title: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              'https://layn.su/assets/images/logo.png',
              height: 32,
              width: 32,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(Icons.play_circle_fill,
                  size: 32, color: theme.colorScheme.primary),
            ),
          ),
          const SizedBox(width: 8),
          Text('Layn',
              style: TextStyle(
                  color: theme.textTheme.titleLarge?.color,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5)),
        ]),
        actions: [
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.notifications_outlined,
                    color: theme.textTheme.titleMedium?.color, size: 26),
                if (_unreadCount > 0)
                  Positioned(
                    right: -5,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: theme.scaffoldBackgroundColor,
                          width: 1.5,
                        ),
                      ),
                      constraints: const BoxConstraints(minWidth: 17),
                      child: Text(
                        _unreadCount > 99 ? '99+' : '$_unreadCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: _openNotifications,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(children: [
        // Category bar with smooth hide/show (collapses space)
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: _categoryVisible
              ? SizedBox(height: 48, child: _buildCategories(theme, isDark))
              : const SizedBox(height: 0),
        ),
        Expanded(child: _buildBody(theme)),
      ]),
    );
  }

  Widget _buildCategories(ThemeData theme, bool isDark) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          _catChip('Все', null, theme, isDark),
          ..._categories.map((c) => _catChip(c.name, c.slug, theme, isDark)),
        ],
      ),
    );
  }

  Widget _catChip(String label, String? slug, ThemeData theme, bool isDark) {
    final active = _selectedCategory == slug;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => _onCategorySelected(slug),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? theme.colorScheme.primary
                : (isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF0F0F0)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active
                  ? theme.colorScheme.primary
                  : (isDark ? const Color(0xFF333333) : const Color(0xFFDDDDDD)),
              width: 1,
            ),
          ),
          child: Text(label,
              style: TextStyle(
                color: active ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[700]),
                fontSize: 13,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              )),
        ),
      ),
    );
  }

  int get _totalItems => _videoCountWithAds + (_loadingMore ? 1 : 0);

  /// Яндекс-реклама в ленте включена (из админки) и есть unit id
  bool get _feedYandexEnabled {
    final s = AdService();
    return s.yandexActive && s.feedEnabled && s.bannerUnitId.isNotEmpty;
  }

  int get _yandexInterval => AdService().feedInterval.clamp(2, 20);

  /// Маркер Яндекс-баннера в ленте (отличается от своих Ad-карточек)
  static const _yandexBannerKey = '__yandex_banner_feed__';

  /// Маркер крупного Яндекс-«видео»-блока в ленте.
  /// Чередуется с обычным баннером: первый рекламный блок — видео-блок,
  /// второй — широкий баннер, и так далее.
  static const _yandexLargeKey = '__yandex_banner_feed_large__';

  /// Список элементов ленты: видео + реклама (свои карточки ИЛИ Яндекс).
  /// Если Яндекс включён — каждые N постов вставляется реклама: крупный
  /// «видео»-блок и широкий баннер чередуются (видео → баннер → видео → …).
  /// Свои Ad-карточки в ленте при этом не показываются (приоритет Яндекса).
  List<dynamic> get _feedItems {
    final items = <dynamic>[];
    int videoIdx = 0;
    int adSlot = 0;
    for (int i = 0; i < _videos.length; i++) {
      items.add(_videos[i]);
      videoIdx++;
      if (_feedYandexEnabled) {
        if (videoIdx % _yandexInterval == 0) {
          // Чередование объявлений: 0 → видео-блок, 1 → широкий баннер, …
          items.add(adSlot % 2 == 0 ? _yandexLargeKey : _yandexBannerKey);
          adSlot++;
        }
      } else if (_ads.isNotEmpty) {
        final ad = _ads.first;
        if (videoIdx > ad.startAfter &&
            (videoIdx - ad.startAfter) % ad.interval == 0) {
          items.add(ad);
        }
      }
    }
    return items;
  }

  int get _videoCountWithAds => _feedItems.length;

  dynamic _itemAt(int flatIndex) => _feedItems[flatIndex];

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: theme.colorScheme.primary),
      );
    }
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, color: Colors.red, size: 48),
        const SizedBox(height: 12),
        Text(_error!, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
        FilledButton(onPressed: _loadVideos, child: const Text('Повторить')),
      ]));
    }
    if (_videos.isEmpty) {
      return Center(
        child: Text('Нет видео',
            style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodySmall?.color)),
      );
    }
    return NotificationListener<ScrollEndNotification>(
      onNotification: (notification) {
        _onScrollEnd();
        return false;
      },
      child: RefreshIndicator(
        color: theme.colorScheme.primary,
        onRefresh: _loadVideos,
        child: ListView.builder(
          controller: _scrollCtrl,
          // Отступ снизу = системный inset + высота капсулы (62) + зазор (24),
          // чтобы последнее видео не пряталось за плавающим меню
          padding: EdgeInsets.only(
            top: 4,
            bottom: MediaQuery.of(context).padding.bottom + 86,
          ),
          itemCount: _totalItems,
          itemBuilder: (_, i) {
            if (i == _videoCountWithAds) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: CircularProgressIndicator(color: theme.colorScheme.primary),
                ),
              );
            }
            final item = _itemAt(i);
            if (item is Ad) {
              return AdCard(ad: item);
            }
            if (item == _yandexBannerKey) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: YandexBanner(placement: AdPlacement.feed),
              );
            }
            if (item == _yandexLargeKey) {
              // Крупный рекламный блок («видео»-формат) — показывается как
              // полноширинный блок, чередуясь с широким баннером.
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: YandexBanner(
                  placement: AdPlacement.feedLarge,
                  height: 320,
                ),
              );
            }
            final video = item as Video;
            return VideoCard(
              video: video,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => VideoScreen(video: video, related: _videos))),
            );
          },
        ),
      ),
    );
  }
}
