import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:provider/provider.dart';
import 'search_screen.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';

class ShortsScreen extends StatefulWidget {
  const ShortsScreen({super.key});

  @override
  State<ShortsScreen> createState() => _ShortsScreenState();
}

class _ShortsScreenState extends State<ShortsScreen> {
  List<Short> _shorts = [];
  bool _loading = true;
  bool _loadingMore = false;
  int _currentPage = 1;
  bool _hasMore = true;
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  // Video
  VideoPlayerController? _vpc;
  bool _isPlaying = false;
  bool _isInitialized = false;
  bool _isMuted = false;

  // Like
  final Map<int, bool> _likedMap = {};
  
  // Subscribe
  final Map<int, bool> _subscribedMap = {};

  // Double tap
  bool _showHeart = false;
  Timer? _heartTimer;
  DateTime? _lastTap;
  Offset _heartPosition = Offset.zero;

  // Play/pause
  bool _showPlayIcon = false;
  Timer? _hidePlayTimer;

  // Progress
  double _progress = 0.0;
  Timer? _progressTimer;
  bool _seeking = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
      statusBarIconBrightness: Brightness.light,
    ));
    _loadShorts();
  }

  Future<void> _loadShorts() async {
    setState(() => _loading = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final rawData = await api.shorts(page: _currentPage);
      final newShorts = Short.fromResponse({'data': {'shorts': rawData}});
      if (mounted) {
        setState(() {
          _shorts.addAll(newShorts);
          _loading = false;
          if (newShorts.isEmpty) _hasMore = false;
        });
        if (_shorts.isNotEmpty && _currentPage == 1) {
          int firstPlayable = 0;
          for (int i = 0; i < _shorts.length; i++) {
            if (_shorts[i].videoUrl.isNotEmpty) {
              firstPlayable = i;
              break;
            }
          }
          _playVideo(firstPlayable);
        }
      }
    } catch (e) {
      debugPrint('Shorts load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    _currentPage++;
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final rawData = await api.shorts(page: _currentPage);
      final newShorts = Short.fromResponse({'data': {'shorts': rawData}});
      if (mounted) {
        setState(() {
          _shorts.addAll(newShorts);
          _loadingMore = false;
          if (newShorts.isEmpty) _hasMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _playVideo(int index) async {
    if (index < 0 || index >= _shorts.length) return;
    _vpc?.dispose();
    _progressTimer?.cancel();

    final url = abs(_shorts[index].videoUrl);
    if (url.isEmpty) {
      setState(() {
        _isInitialized = false;
        _isPlaying = false;
        _progress = 0.0;
      });
      return;
    }

    setState(() {
      _isInitialized = false;
      _isPlaying = false;
      _progress = 0.0;
    });

    try {
      _vpc = VideoPlayerController.networkUrl(Uri.parse(url));
      await _vpc!.initialize();
      if (!mounted) return;
      _vpc!.setLooping(true);
      _vpc!.setVolume(_isMuted ? 0 : 1);
      await _vpc!.play();

      _progressTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
        if (_vpc != null && _vpc!.value.isInitialized && mounted && !_seeking) {
          final dur = _vpc!.value.duration.inMilliseconds;
          if (dur > 0) {
            setState(() {
              _progress = _vpc!.value.position.inMilliseconds / dur;
            });
          }
        }
      });

      if (mounted) setState(() { _isInitialized = true; _isPlaying = true; });
    } catch (e) {
      debugPrint('Shorts play error: $e');
    }
  }

  void _togglePlayPause() {
    if (_vpc == null || !_isInitialized) return;
    if (_vpc!.value.isPlaying) {
      _vpc!.pause();
      setState(() { _isPlaying = false; _showPlayIcon = true; });
    } else {
      _vpc!.play();
      setState(() { _isPlaying = true; _showPlayIcon = true; });
    }
    _hidePlayTimer?.cancel();
    _hidePlayTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _showPlayIcon = false);
    });
  }

  void _toggleMute() {
    if (_vpc == null) return;
    setState(() => _isMuted = !_isMuted);
    _vpc!.setVolume(_isMuted ? 0 : 1);
  }

  void _handleTap(TapDownDetails details) {
    final now = DateTime.now();
    if (_lastTap != null && now.difference(_lastTap!).inMilliseconds < 300) {
      _lastTap = null;
      final short = _shorts[_currentIndex];
      final isLiked = _likedMap[short.id] ?? false;
      if (!isLiked) {
        _likedMap[short.id] = true;
        final api = Provider.of<ApiService>(context, listen: false);
        api.reaction(short.id, 'like').catchError((_) {});
      }
      setState(() {
        _heartPosition = details.localPosition;
        _showHeart = true;
      });
      _heartTimer?.cancel();
      _heartTimer = Timer(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _showHeart = false);
      });
    } else {
      _lastTap = now;
      _togglePlayPause();
    }
  }

  void _onSeek(DragUpdateDetails details) {
    if (_vpc == null || !_vpc!.value.isInitialized) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final dx = details.localPosition.dx.clamp(0.0, box.size.width);
    final pct = dx / box.size.width;
    setState(() { _progress = pct; _seeking = true; });
  }

  void _onSeekEnd(DragEndDetails details) {
    if (_vpc == null || !_vpc!.value.isInitialized) return;
    final dur = _vpc!.value.duration;
    final pos = Duration(milliseconds: (dur.inMilliseconds * _progress).round());
    _vpc!.seekTo(pos);
    setState(() => _seeking = false);
  }

  @override
  void dispose() {
    _heartTimer?.cancel();
    _hidePlayTimer?.cancel();
    _progressTimer?.cancel();
    _vpc?.dispose();
    _pageController.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/logo.png', width: 60, height: 60,
                  errorBuilder: (_, __, ___) => Icon(Icons.play_circle_fill,
                      size: 60, color: Colors.red.shade400)),
              const SizedBox(height: 16),
              const SizedBox(width: 24, height: 24,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            ],
          ),
        ),
      );
    }
    if (_shorts.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.play_circle_outline, size: 64,
                  color: Colors.white.withOpacity(0.5)),
              const SizedBox(height: 12),
              Text('Нет шортсов',
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16)),
            ],
          ),
        ),
      );
    }

    final padding = MediaQuery.of(context).padding;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // === PAGE VIEW — ALL UI INSIDE per-page ===
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              physics: const PageScrollPhysics(),
              itemCount: _shorts.length,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
                _playVideo(index);
                if (index >= _shorts.length - 3) _loadMore();
              },
              itemBuilder: (context, index) {
                final short = _shorts[index];
                final isCurrent = index == _currentIndex;
                final isLiked = _likedMap[short.id] ?? false;

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // === VIDEO ===
                    if (isCurrent && _isInitialized && _vpc != null)
                      Center(
                        child: AspectRatio(
                          aspectRatio: _vpc!.value.aspectRatio > 0
                              ? _vpc!.value.aspectRatio : 9 / 16,
                          child: VideoPlayer(_vpc!),
                        ),
                      )
                    else if (isCurrent)
                      _buildSkeleton(short)
                    else
                      CachedNetworkImage(
                        imageUrl: short.thumbnailUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(color: Colors.black),
                      ),

                    // === TAP OVERLAY (play/pause + double tap like) ===
                    if (isCurrent)
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTapDown: _handleTap,
                          child: Container(color: Colors.transparent),
                        ),
                      ),

                    // === BOTTOM GRADIENT ===
                    Positioned(
                      left: 0, right: 0, bottom: 0,
                      child: IgnorePointer(
                        child: Container(
                          height: 280,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black87],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // === TOP GRADIENT ===
                    Positioned(
                      left: 0, right: 0, top: 0,
                      child: IgnorePointer(
                        child: Container(
                          height: 80 + padding.top,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [Colors.transparent, Colors.black54],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // === TOP BAR ===
                    Positioned(
                      top: 0, left: 0, right: 0,
                      child: Container(
                        padding: EdgeInsets.fromLTRB(16, padding.top + 8, 16, 8),
                        child: Row(
                          children: [
                            const Icon(Icons.play_circle, color: Colors.white, size: 24),
                            const SizedBox(width: 8),
                            const Text('Shorts',
                                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            const Spacer(),
                            GestureDetector(
                              onTap: _toggleMute,
                              child: Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.4),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(_isMuted ? Icons.volume_off : Icons.volume_up,
                                    color: Colors.white, size: 18),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.search, color: Colors.white),
                              onPressed: () => Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => const SearchScreen())),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // === BOTTOM INFO (avatar + channel + subscribe, then title) ===
                    Positioned(
                      left: 12, right: 72,
                      bottom: 52,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Row: avatar + channel name + subscribe
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: Colors.grey.shade800,
                                backgroundImage: short.avatar.isNotEmpty
                                    ? CachedNetworkImageProvider(abs(short.avatar))
                                    : null,
                                child: short.avatar.isEmpty
                                    ? Text(short.channelName.isNotEmpty
                                        ? short.channelName[0].toUpperCase() : '?',
                                        style: const TextStyle(fontSize: 11, color: Colors.white))
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  short.channelName.isNotEmpty ? short.channelName : short.username,
                                  style: const TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14,
                                    shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                                  ),
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (short.userId != null && short.userId != auth.userId)
                                GestureDetector(
                                  onTap: () async {
                                    if (!auth.isAuth) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Войдите, чтобы подписаться')),
                                      );
                                      return;
                                    }
                                    final isSub = _subscribedMap[short.userId] ?? false;
                                    try {
                                      final api = Provider.of<ApiService>(context, listen: false);
                                      await api.subscribe(short.userId!);
                                      setState(() => _subscribedMap[short.userId!] = !isSub);
                                    } catch (_) {}
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: (_subscribedMap[short.userId] ?? false)
                                          ? Colors.white.withOpacity(0.25)
                                          : Colors.red,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      (_subscribedMap[short.userId] ?? false) ? 'Подписка' : 'Подписаться',
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Title
                          Text(
                            short.title,
                            style: const TextStyle(
                              color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500, height: 1.3,
                              shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                            ),
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          if (short.views > 0)
                            Text(
                              '${_formatViews(short.views)} просмотров',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85), fontSize: 12,
                                shadows: const [Shadow(blurRadius: 3, color: Colors.black54)],
                              ),
                            ),
                        ],
                      ),
                    ),

                    // === RIGHT SIDE BUTTONS ===
                    Positioned(
                      right: 8, bottom: 120,
                      child: Column(
                        children: [
                          _actionButton(
                            icon: isLiked ? Icons.favorite : Icons.favorite_border,
                            color: isLiked ? Colors.red : Colors.white,
                            label: _formatCount(short.likesCount + (isLiked ? 1 : 0)),
                            onTap: () async {
                              final auth = Provider.of<AuthProvider>(context, listen: false);
                              if (!auth.isAuth) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Войдите, чтобы ставить лайки')),
                                );
                                return;
                              }
                              try {
                                final api = Provider.of<ApiService>(context, listen: false);
                                await api.reaction(short.id, 'like');
                                setState(() => _likedMap[short.id] = !isLiked);
                              } catch (_) {}
                            },
                          ),
                          const SizedBox(height: 20),
                          _actionButton(
                            icon: Icons.chat_bubble_outline, color: Colors.white,
                            label: _formatCount(short.commentsCount),
                            onTap: () => _showCommentsSheet(short),
                          ),
                          const SizedBox(height: 20),
                          _actionButton(
                            icon: Icons.share, color: Colors.white,
                            onTap: () => Share.share(short.shareUrl),
                          ),
                          const SizedBox(height: 20),
                          _actionButton(
                            icon: Icons.more_vert, color: Colors.white,
                            onTap: () => _showMoreSheet(short),
                          ),
                        ],
                      ),
                    ),

                    // === DOUBLE TAP HEART ===
                    if (isCurrent && _showHeart)
                      Positioned(
                        left: _heartPosition.dx - 36,
                        top: _heartPosition.dy - 36,
                        child: IgnorePointer(
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: const Duration(milliseconds: 300),
                            builder: (_, scale, child) => Transform.scale(
                              scale: scale,
                              child: Opacity(
                                opacity: (1.0 - scale).clamp(0.0, 1.0),
                                child: child,
                              ),
                            ),
                            child: const Icon(Icons.favorite, color: Colors.red, size: 72),
                          ),
                        ),
                      ),

                    // === PLAY/PAUSE CENTER ===
                    if (isCurrent && _showPlayIcon)
                      IgnorePointer(
                        child: Center(
                          child: AnimatedOpacity(
                            opacity: _showPlayIcon ? 0.8 : 0.0,
                            duration: const Duration(milliseconds: 150),
                            child: Container(
                              width: 64, height: 64,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5), shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _isPlaying ? Icons.play_arrow : Icons.pause,
                                color: Colors.white, size: 40,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),

          // === FIXED RED PROGRESS BAR ===
          GestureDetector(
            onHorizontalDragUpdate: _onSeek,
            onHorizontalDragEnd: _onSeekEnd,
            onTapDown: (d) {
              if (_vpc == null || !_vpc!.value.isInitialized) return;
              final box = context.findRenderObject() as RenderBox?;
              if (box == null) return;
              final w = box.size.width;
              final dx = d.localPosition.dx.clamp(0.0, w);
              final pct = dx / w;
              final dur = _vpc!.value.duration;
              final pos = Duration(milliseconds: (dur.inMilliseconds * pct).round());
              _vpc!.seekTo(pos);
              setState(() => _progress = pct);
            },
            child: Container(
              color: Colors.black,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_seeking)
                    Align(
                      alignment: Alignment(_progress * 2 - 1, 0),
                      child: Container(
                        width: 12, height: 12,
                        margin: const EdgeInsets.only(bottom: 2),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      ),
                    ),
                  SizedBox(
                    height: 3,
                    child: LinearProgressIndicator(
                      value: _progress.clamp(0.0, 1.0),
                      backgroundColor: Colors.white.withOpacity(0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton(Short short) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: short.thumbnailUrl,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            color: Colors.black,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
          ),
          errorWidget: (_, __, ___) => Container(
            color: Colors.black,
            child: const Center(
              child: Icon(Icons.error_outline, color: Colors.white54, size: 48)),
          ),
        ),
        if (!_isInitialized)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(width: 36, height: 36,
                      child: CircularProgressIndicator(
                          color: Colors.white.withOpacity(0.8), strokeWidth: 2)),
                  const SizedBox(height: 12),
                  Text('Загрузка...',
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _formatViews(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M ';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K ';
    return '$n ';
  }

  Widget _actionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    String? label,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 28),
          if (label != null && label.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
            ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  void _showCommentsSheet(Short short) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5, minChildSize: 0.3, maxChildSize: 0.85,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            Container(width: 40, height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(color: Colors.grey.shade600,
                    borderRadius: BorderRadius.circular(2))),
            const Text('Комментарии',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const Divider(height: 1),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 48,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 12),
                    Text('Комментарии скоро появятся',
                        style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMoreSheet(Short short) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(color: Colors.grey.shade600,
                    borderRadius: BorderRadius.circular(2))),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Поделиться'),
              onTap: () { Navigator.pop(ctx); Share.share(short.shareUrl); },
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Пожаловаться'),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('Не интересует'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }
}
