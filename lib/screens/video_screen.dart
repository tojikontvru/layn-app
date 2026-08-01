import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/ad_service.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import '../widgets/video_card.dart';

class VideoScreen extends StatefulWidget {
  final Video video;
  final List<Video>? related;

  const VideoScreen({super.key, required this.video, this.related});

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  ChewieController? _cc;
  VideoPlayerController? _vpc;
  bool _loading = true;
  static const _mediaChannel = MethodChannel('su.layn.app/media');
  String? _lastMetadataTitle;
  bool _lastPlayingState = true;
  bool _liked = false;
  bool _disliked = false;
  int _likeCount = 0;
  bool _subscribed = false;
  List<Comment> _comments = [];
  bool _showDescription = false;
  int _selectedTab = 0;
  bool _disposed = false;
  String? _videoError;

  late String _shareUrl;

  late AnimationController _animCtrl;
  late Animation<double> _likeAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _likeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 0.9), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 40),
    ]).animate(_animCtrl);
    _likeCount = widget.video.likesCount ?? 0;
    _shareUrl = widget.video.shareUrl;
    _mediaChannel.setMethodCallHandler(_handleMediaCommand);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      // HLS-стрим стартует мгновенно (маленький манифест + сегменты).
      // Если сервер отдаёт HLS — используем его, иначе fallback на MP4.
      final rawUrl = (widget.video.hlsUrl != null &&
              widget.video.hlsUrl!.isNotEmpty)
          ? widget.video.hlsUrl!
          : widget.video.videoUrl;
      final url = abs(rawUrl);
      if (url.isEmpty) {
        setState(() {
          _loading = false;
          _videoError = 'Ссылка на видео отсутствует';
        });
        return;
      }
      // Создаём контроллер сразу при открытии экрана.
      // httpHeaders можно использовать для авторизованных стримов
      // (например, Bearer-токен), videoPlayerOptions — быстрый старт.
      _vpc = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: const {},
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );
      await _vpc!.initialize();
      if (_disposed) return;
      _cc = ChewieController(
        videoPlayerController: _vpc!,
        autoPlay: true,
        looping: false,
        aspectRatio: _vpc!.value.aspectRatio > 0
            ? _vpc!.value.aspectRatio
            : 16 / 9,
        allowFullScreen: true,
        allowMuting: true,
        showControlsOnInitialize: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: Theme.of(context).colorScheme.primary,
          handleColor: Theme.of(context).colorScheme.primary,
          bufferedColor: Colors.grey.shade700,
        ),
        placeholder: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              widget.video.thumb,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: Colors.black),
              loadingBuilder: (_, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: Colors.black,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      child,
                      const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white54,
                          strokeWidth: 2,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const Center(
              child: CircularProgressIndicator(
                color: Colors.white54,
                strokeWidth: 2,
              ),
            ),
          ],
        ),
        errorBuilder: (_, msg) => Container(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 8),
                Text(msg,
                    style: const TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ),
      );
      WakelockPlus.enable();

    // Auto-play next video when current ends
    if (widget.related != null && widget.related!.isNotEmpty) {
      _vpc!.addListener(() {
        if (_vpc!.value.position >= _vpc!.value.duration - const Duration(milliseconds: 500) &&
            _vpc!.value.duration > Duration.zero &&
            !_disposed) {
          _playNextVideo();
        }
      });
    }
      if (mounted) {
        setState(() => _loading = false);
        _sendMetadata(isPlaying: true);
      }
    } catch (e) {
      if (!_disposed && mounted) {
        setState(() {
          _loading = false;
          _videoError = 'Не удалось загрузить видео';
        });
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _releaseMediaSession();
    _animCtrl.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _cc?.dispose();
    _vpc?.dispose();
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cc == null) return;
    if (state == AppLifecycleState.resumed) {
      _cc!.play();
    }
  }

  void _playNextVideo() {
    if (!mounted) return;
    if (_disposed) return;
    final related = widget.related?.where((v) => v.id != widget.video.id).toList();
    if (related == null || related.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Плейлист завершён'), duration: Duration(seconds: 1), backgroundColor: Colors.black87),
        );
      }
      return;
    }
    final next = related.first;
    _cc?.pause(); _vpc?.pause();

    // Показываем рекламу перед следующим видео
    AdService().showYandexInterstitial();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.play_circle_outline, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(next.title.isNotEmpty ? next.title : 'Следующее видео', overflow: TextOverflow.ellipsis)),
        ]),
        duration: const Duration(seconds: 2), backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
      ));
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => VideoScreen(video: next, related: widget.related)));
      });
    }
  }


  void _sendMetadata({bool isPlaying = true}) {
    final title = widget.video.title.isNotEmpty ? widget.video.title : 'Видео без названия';
    final channel = widget.video.user?.username ?? '';
    if (title == _lastMetadataTitle && isPlaying == _lastPlayingState) return;
    _lastMetadataTitle = title;
    _lastPlayingState = isPlaying;
    try { _mediaChannel.invokeMethod('update', {'title': title, 'channel': channel, 'isPlaying': isPlaying}); } catch (_) {}
  }

  Future<dynamic> _handleMediaCommand(MethodCall call) async {
    switch (call.method) {
      case 'onPlay': _cc?.play(); _sendMetadata(isPlaying: true); break;
      case 'onPause': _cc?.pause(); _sendMetadata(isPlaying: false); break;
      case 'onStop': _releaseMediaSession(); break;
    }
  }

  void _releaseMediaSession() {
    try { _mediaChannel.invokeMethod('release'); } catch (_) {}
    _lastMetadataTitle = null;
  }

  String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  String _formatViews(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M просмотров';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K просмотров';
    return '$n просмотров';
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inDays > 365) return '${(diff.inDays / 365).floor()} г. назад';
      if (diff.inDays > 30) return '${(diff.inDays / 30).floor()} мес. назад';
      if (diff.inDays > 0) return '${diff.inDays} дн. назад';
      if (diff.inHours > 0) return '${diff.inHours} ч. назад';
      if (diff.inMinutes > 0) return '${diff.inMinutes} мин. назад';
      return 'Только что';
    } catch (_) {
      return dateStr;
    }
  }

  Future<void> _onLike() async {
    _animCtrl.forward(from: 0);
    final api = Provider.of<ApiService>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuth) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Войдите, чтобы ставить лайки')),
      );
      return;
    }
    try {
      await api.reaction(widget.video.id, 'like');
      setState(() {
        _liked = !(_disliked || _liked);
        if (_liked) {
          _likeCount++;
          _disliked = false;
        } else {
          _likeCount = _likeCount > 0 ? _likeCount - 1 : 0;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  Future<void> _onDislike() async {
    final api = Provider.of<ApiService>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuth) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Войдите, чтобы ставить дизлайки')),
      );
      return;
    }
    try {
      await api.reaction(widget.video.id, 'dislike');
      setState(() {
        _disliked = !_disliked;
        if (_disliked) {
          _liked = false;
          _likeCount = _likeCount > 0 ? _likeCount - 1 : 0;
        }
      });
    } catch (_) {}
  }

  Future<void> _onSubscribe() async {
    final api = Provider.of<ApiService>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuth) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Войдите, чтобы подписаться')),
      );
      return;
    }
    if (widget.video.userId != null && widget.video.userId == auth.userId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нельзя подписаться на свой канал')),
      );
      return;
    }
    try {
      await api.subscribe(widget.video.userId ?? 0);
      setState(() => _subscribed = !_subscribed);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  Future<void> _loadComments() async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      _comments = await api.comments(widget.video.id);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isMyVideo = widget.video.userId != null &&
        widget.video.userId == auth.userId;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // Video player — NO header above it, just SafeArea padding
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                if (_loading)
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Постер видео виден СРАЗУ, пока инициализируется плеер
                        CachedNetworkImage(
                          imageUrl: widget.video.thumb,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              Container(color: Colors.black),
                          placeholder: (_, __) => Container(color: Colors.black),
                        ),
                        const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white70,
                            strokeWidth: 2,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_videoError != null)
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      color: Colors.black,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 48),
                            const SizedBox(height: 8),
                            Text(_videoError!,
                                style: const TextStyle(color: Colors.white),
                                textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _loading = true;
                                  _videoError = null;
                                });
                                _initVideo();
                              },
                              child: const Text('Повторить',
                                  style: TextStyle(color: Color(0xFF3EA6FF))),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else if (_cc != null)
                  AspectRatio(
                    aspectRatio: _cc!.videoPlayerController.value.aspectRatio > 0
                        ? _cc!.videoPlayerController.value.aspectRatio
                        : 16 / 9,
                    child: Chewie(controller: _cc!),
                  )
                else
                  Container(
                    height: 200,
                    color: Colors.black,
                    child: const Center(
                      child: Text('Не удалось загрузить видео',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Title
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(
                    widget.video.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Views + date + "Ещё" for description
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: GestureDetector(
                    onTap: () => setState(() => _showDescription = !_showDescription),
                    child: Row(
                      children: [
                        Text(
                          '${_formatViews(widget.video.views)} · ${_formatDate(widget.video.createdAt)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _showDescription ? 'Свернуть' : 'Ещё',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Combined row: [Avatar] [Name] [+] [Playlist] [♡ count] [Share]
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      // Channel avatar
                      CircleAvatar(
                        radius: 16,
                        backgroundImage: widget.video.avatar != null &&
                                widget.video.avatar!.isNotEmpty
                            ? CachedNetworkImageProvider(abs(widget.video.avatar!))
                            : null,
                        child: widget.video.avatar == null || widget.video.avatar!.isEmpty
                            ? Text(
                                widget.video.channel.isNotEmpty
                                    ? widget.video.channel[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      // Channel name
                      Flexible(
                        child: Text(
                          widget.video.channel,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Subscribe [+] button (circle)
                      if (!isMyVideo)
                        GestureDetector(
                          onTap: _onSubscribe,
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: _subscribed
                                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                                  : Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                              border: _subscribed
                                  ? Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.3))
                                  : null,
                            ),
                            child: Icon(
                              _subscribed ? Icons.check : Icons.add,
                              size: 16,
                              color: _subscribed
                                  ? Theme.of(context).textTheme.bodyLarge?.color
                                  : Colors.white,
                            ),
                          ),
                        ),
                      const Spacer(),
                      const Spacer(),
                      // Playlist — жирная иконка
                      GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Плейлисты — скоро'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        child: Icon(
                          Icons.playlist_add_rounded,
                          size: 26,
                          weight: 700,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                      const SizedBox(width: 22),
                      // Like 👍 — жирная иконка с реальным счётчиком
                      GestureDetector(
                        onTap: _onLike,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedBuilder(
                              animation: _animCtrl,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _likeAnim.value,
                                  child: Icon(
                                    _liked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
                                    size: 26,
                                    weight: 700,
                                    color: _liked ? Theme.of(context).colorScheme.primary : Theme.of(context).textTheme.bodySmall?.color,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatCount(_likeCount),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _liked
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).textTheme.bodySmall?.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 22),
                      // Share — жирная иконка
                      GestureDetector(
                        onTap: () => Share.share(_shareUrl),
                        child: Icon(
                          Icons.share_rounded,
                          size: 26,
                          weight: 700,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),

                // Description expanded
                if (_showDescription) ...[
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.video.description.isNotEmpty)
                          Text(
                            widget.video.description,
                            style: const TextStyle(fontSize: 13),
                          )
                        else
                          Text(
                            'Описание отсутствует',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).textTheme.bodySmall?.color,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 8),

                // Tabs: Похожие / Комментарии
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedTab = 0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: _selectedTab == 0
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Похожие',
                              style: TextStyle(
                                fontWeight: _selectedTab == 0 ? FontWeight.w600 : FontWeight.normal,
                                color: _selectedTab == 0
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).textTheme.bodySmall?.color,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selectedTab = 1);
                          _loadComments();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: _selectedTab == 1
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Комментарии',
                              style: TextStyle(
                                fontWeight: _selectedTab == 1 ? FontWeight.w600 : FontWeight.normal,
                                color: _selectedTab == 1
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).textTheme.bodySmall?.color,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Tab content
                if (_selectedTab == 0) ...[
                  if (widget.related != null && widget.related!.isNotEmpty)
                    ...widget.related!
                        .where((v) => v.id != widget.video.id)
                        .map((v) => VideoCard(
                              video: v,
                              onTap: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => VideoScreen(video: v, related: widget.related),
                                  ),
                                );
                              },
                            ))
                  else
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('Нет похожих видео')),
                    ),
                ] else ...[
                  if (_comments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    ..._comments.map((c) => _buildComment(c)),
                  _buildCommentInput(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ytAction(
      IconData icon, IconData? activeIcon, String label, VoidCallback onTap) {
    final isActive = activeIcon != null;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? activeIcon : icon,
            size: 22,
            color: isActive ? Theme.of(context).colorScheme.primary : null,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComment(Comment c) {
    final uname = c.user?.username ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundImage: c.user?.avatar != null && c.user!.avatar!.isNotEmpty
                ? CachedNetworkImageProvider(abs(c.user!.avatar!))
                : null,
            child: uname.isEmpty || c.user?.avatar == null || c.user!.avatar!.isEmpty
                ? Text(
                    uname.isNotEmpty ? uname[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 12),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  uname,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(c.text, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    final ctrl = TextEditingController();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          const CircleAvatar(radius: 14, child: Icon(Icons.person, size: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: ctrl,
              decoration: InputDecoration(
                hintText: 'Добавить комментарий...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.send,
                size: 20, color: Theme.of(context).colorScheme.primary),
            onPressed: () async {
              final text = ctrl.text.trim();
              if (text.isEmpty) return;
              final api = Provider.of<ApiService>(context, listen: false);
              final auth = Provider.of<AuthProvider>(context, listen: false);
              if (!auth.isAuth) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Войдите, чтобы оставить комментарий')),
                );
                return;
              }
              try {
                await api.sendComment(widget.video.id, text);
                ctrl.clear();
                _loadComments();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ошибка: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
