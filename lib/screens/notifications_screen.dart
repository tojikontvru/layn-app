import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:layn_app/models/models.dart';
import 'package:layn_app/services/api_service.dart';

/// Экран уведомлений/новостей в стиле Telegram-канала.
/// Лента постов из админки (push-рассылки) + плашка Mute/Unmute внизу.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const _mutedKey = 'notifications_muted';

  List<AppNotification> _items = [];
  bool _loading = true;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    _loadMuted();
    _fetch();
  }

  Future<void> _loadMuted() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _muted = prefs.getBool(_mutedKey) ?? false);
  }

  Future<void> _toggleMuted(bool value) async {
    setState(() => _muted = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_mutedKey, value);
    // Лёгкая обратная связь (локальное переключение; при подключении FCM
    // здесь будет отправка статуса подписки на бэкенд).
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? 'Уведомления отключены' : 'Уведомления включены'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final list = await ApiService.instance.notifications();
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
    });
    // Помечаем всё прочитанным: запоминаем максимальный id поста.
    // Бейдж на колокольчике считается от lastSeenPostId.
    if (list.isNotEmpty) {
      final maxId = list.map((n) => n.id).reduce((a, b) => a > b ? a : b);
      final prefs = await SharedPreferences.getInstance();
      final lastSeen = prefs.getInt('lastSeenPostId') ?? 0;
      if (maxId > lastSeen) {
        await prefs.setInt('lastSeenPostId', maxId);
      }
    }
  }

  String _formatDate(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'только что';
      if (diff.inHours < 1) return '${diff.inMinutes} мин. назад';
      if (diff.inDays < 1) return '${diff.inHours} ч. назад';
      if (diff.inDays < 7) return '${diff.inDays} дн. назад';
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Цвета баблов в стиле Telegram
    final bubbleColor = isDark ? const Color(0xFF1C2733) : const Color(0xFFEFFDEF);
    final screenBg = isDark ? const Color(0xFF0F0F0F) : Colors.white;

    return Scaffold(
      backgroundColor: screenBg,
      appBar: AppBar(
        backgroundColor: screenBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Уведомления'),
        actions: [
          IconButton(
            icon: Icon(
              _muted ? Icons.notifications_off_outlined : Icons.notifications_active_outlined,
              color: _muted ? Colors.grey : theme.colorScheme.primary,
            ),
            onPressed: () => _toggleMuted(!_muted),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? _buildEmpty(isDark)
                    : RefreshIndicator(
                        onRefresh: _fetch,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                          itemCount: _items.length,
                          itemBuilder: (context, i) => _buildBubble(_items[i], bubbleColor, isDark),
                        ),
                      ),
          ),
          // Закреплённая плашка управления уведомлениями
          _buildMuteBar(isDark),
        ],
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_none,
            size: 56,
            color: isDark ? Colors.white24 : Colors.black26,
          ),
          const SizedBox(height: 12),
          Text(
            'Пока нет уведомлений',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white38 : Colors.black45,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Новости канала появятся здесь',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          ),
        ],
      ),
    );
  }

  /// Бабл поста — как в Telegram-канале
  Widget _buildBubble(AppNotification n, Color bubbleColor, bool isDark) {
    final hasImage = n.image.isNotEmpty;
    final hasVideo = n.video.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.82,
          ),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(14),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasVideo) ...[
                _NotificationVideoPlayer(url: n.video),
                const SizedBox(height: 10),
              ] else if (hasImage) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: n.image,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    // Плейсхолдер того же цвета, что и бабл, чтобы пост не «прыгал»
                    // и картинка не была белым прямоугольником во время загрузки.
                    placeholder: (_, __) => Container(
                      height: 180,
                      color: isDark ? const Color(0xFF161D26) : const Color(0xFFE4F2E4),
                      child: const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              // Заголовок показываем только если он НЕ дублирует текст кнопки
              // (в старых постах subject = btn_title из-за старой логики бэкенда)
              if (n.subject.isNotEmpty &&
                  !(n.links.isNotEmpty && n.subject == n.links.first.text)) ...[
                Text(
                  n.subject,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              if (n.message.isNotEmpty)
                Text(
                  n.message,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              if (n.links.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: n.links
                      .map(
                        (l) => _buildLinkButton(l, isDark),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                _formatDate(n.createdAt),
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Кнопка-ссылка внутри поста (переход по ссылке или видео).
  /// Видео-ссылки — красная кнопка, внешние ссылки — синяя.
  Widget _buildLinkButton(AppLink l, bool isDark) {
    final isVideo = _isVideoUrl(l.url);
    final Color bgColor;
    if (isVideo) {
      bgColor = isDark ? const Color(0xFF8E1F1F) : const Color(0xFFE53935);
    } else {
      bgColor = isDark ? const Color(0xFF2A4B7C) : const Color(0xFF065FD4);
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _openLink(l.url),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isVideo ? Icons.play_circle_outline : Icons.open_in_new,
                size: 16,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
              Text(
                l.text.isNotEmpty ? l.text : l.url,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isVideoUrl(String url) {
    final u = url.toLowerCase();
    return u.contains('.mp4') ||
        u.contains('.webm') ||
        u.contains('.mov') ||
        u.contains('/play/') ||
        u.contains('/watch/') ||
        u.contains('/video/') ||
        u.contains('youtube.com') ||
        u.contains('youtu.be') ||
        u.contains('vimeo.com');
  }

  /// Открытие ссылки кнопки поста.
  /// Внешние ссылки — в браузере. Внутренние ссылки на видео (/play/{id} или
  /// прямой .mp4) — показываем встроенным плеером прямо в приложении.
  Future<void> _openLink(String url) async {
    if (_isVideoUrl(url)) {
      // Внутреннее видео сайта: /play/127 → /api/v1/videos/127 → прямой mp4
      var videoUrl = url;
      final playMatch = RegExp(r'/play/(\d+)').firstMatch(url);
      if (playMatch != null) {
        final id = playMatch.group(1);
        try {
          final api = ApiService.instance;
          final resolved = await api.getVideoPlayUrl(id ?? '');
          if (resolved != null && resolved.isNotEmpty) videoUrl = resolved;
        } catch (_) {
          // если не удалось — откроем оригинальный URL (mp4/webm) как есть
        }
      }
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierColor: Colors.black87,
        builder: (_) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: EdgeInsets.zero,
          child: _NotificationVideoPlayer(url: videoUrl),
        ),
      );
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть ссылку')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть ссылку')),
        );
      }
    }
  }

  /// Нижняя плашка «Включить / Отключить уведомления»
  Widget _buildMuteBar(bool isDark) {
    final barColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
      decoration: BoxDecoration(
        color: barColor,
        border: Border(
          top: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _toggleMuted(!_muted),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 13),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: _muted
                  ? (isDark ? Colors.white10 : Colors.black12)
                  : (isDark ? const Color(0xFF2A4B7C) : const Color(0xFF065FD4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _muted ? Icons.notifications_off : Icons.notifications_active,
                  size: 19,
                  color: _muted
                      ? (isDark ? Colors.white54 : Colors.black54)
                      : Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  _muted ? 'Включить уведомления' : 'Отключить уведомления',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _muted
                        ? (isDark ? Colors.white54 : Colors.black54)
                        : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Лёгкий видео-плеер для бабла уведомления: показывает постер-кнопку,
/// по тапу запускает проигрывание (поток с сервера).
class _NotificationVideoPlayer extends StatefulWidget {
  final String url;
  const _NotificationVideoPlayer({required this.url});

  @override
  State<_NotificationVideoPlayer> createState() => _NotificationVideoPlayerState();
}

class _NotificationVideoPlayerState extends State<_NotificationVideoPlayer> {
  bool _playing = false;
  bool _error = false;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: _playing
          ? NotificationVideoView(
              url: widget.url,
              onError: () {
                if (mounted) setState(() => _error = true);
              },
            )
          : InkWell(
              onTap: () => setState(() => _playing = true),
              child: Container(
                width: double.infinity,
                color: Colors.black,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _error ? Icons.error_outline : Icons.play_circle_fill,
                          size: 56,
                          color: _error ? Colors.white38 : Colors.white,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _error ? 'Не удалось воспроизвести' : 'Смотреть видео',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

/// Простое воспроизведение видео (без Chewie, чтобы не тянуть тяжёлые контролы).
class NotificationVideoView extends StatefulWidget {
  final String url;
  final VoidCallback onError;
  const NotificationVideoView({super.key, required this.url, required this.onError});

  @override
  State<NotificationVideoView> createState() => _NotificationVideoViewState();
}

class _NotificationVideoViewState extends State<NotificationVideoView> {
  late final VideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller.initialize().then((_) {
      if (mounted) {
        setState(() => _ready = true);
        _controller.play();
      }
    }).catchError((_) {
      widget.onError();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return Container(
        color: Colors.black,
        // Индикатор загрузки вместо чёрного экрана, пока инициализируется плеер
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white70),
              ),
              SizedBox(height: 10),
              Text(
                'Загрузка видео…',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }
    final size = _controller.value.size;
    // Показываем видео в его реальном соотношении сторон (не обрезая и не сжимая),
    // с ограничением максимальной высоты, чтобы портретные клипы не растягивались
    // на весь экран. 16:9-видео займёт всю ширину, вертикальное — аккуратно по центру.
    final screenWidth = MediaQuery.of(context).size.width - 40; // отступы бабла
    final maxHeight = screenWidth * 1.4;
    final ratio = (size.width > 0 && size.height > 0) ? size.width / size.height : 16 / 9;
    var w = screenWidth;
    var h = screenWidth / ratio;
    if (h > maxHeight) {
      h = maxHeight;
      w = h * ratio;
    }
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: SizedBox(
        width: w,
        height: h,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(_controller),
            // Тап по видео — пауза/продолжить
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() {
                  _controller.value.isPlaying ? _controller.pause() : _controller.play();
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
