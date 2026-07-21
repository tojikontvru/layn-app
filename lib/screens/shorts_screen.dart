import 'dart:async';
import 'dart:math';
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

class _ShortsScreenState extends State<ShortsScreen>
    with SingleTickerProviderStateMixin {
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

  // Double tap like animation
  bool _showHeart = false;
  Timer? _heartTimer;
  DateTime? _lastTap;
  Offset _heartPosition = Offset.zero;

  // Play/pause icon
  bool _showPlayIcon = false;
  Timer? _hidePlayTimer;

  // Progress
  double _progress = 0.0;
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _loadShorts();
  }

  Future<void> _loadShorts() async {
    setState(() => _loading = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final data = await api.shorts(page: _currentPage);
      final newShorts = Short.fromResponse({'data': {'shorts': data}});
      if (mounted) {
        setState(() {
          _shorts.addAll(newShorts);
          _loading = false;
          if (newShorts.isEmpty) _hasMore = false;
        });
        if (_shorts.isNotEmpty && _currentPage == 1) {
          _playVideo(0);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    _currentPage++;
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final data = await api.shorts(page: _currentPage);
      final newShorts = Short.fromResponse({'data': {'shorts': data}});
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

    final short = _shorts[index];
    final url = abs(short.videoUrl);
    if (url.isEmpty) return;

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

      // Listen to progress
      _progressTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
        if (_vpc != null && _vpc!.value.isInitialized && mounted) {
          final dur = _vpc!.value.duration.inMilliseconds;
          if (dur > 0) {
            setState(() {
              _progress = _vpc!.value.position.inMilliseconds / dur;
            });
          }
        }
      });

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isPlaying = true;
        });
      }
    } catch (e) {
      debugPrint('Shorts play error: $e');
    }
  }

  void _togglePlayPause() {
    if (_vpc == null || !_isInitialized) return;
    if (_vpc!.value.isPlaying) {
      _vpc!.pause();
      setState(() {
        _isPlaying = false;
        _showPlayIcon = true;
      });
    } else {
      _vpc!.play();
      setState(() {
        _isPlaying = true;
        _showPlayIcon = true;
      });
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
      // Double tap - like
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

  @override
  void dispose() {
    _heartTimer?.cancel();
    _hidePlayTimer?.cancel();
    _progressTimer?.cancel();
    _vpc?.dispose();
    _pageController.dispose();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
              Image.asset(
                'assets/images/logo.png',
                width: 60,
                height: 60,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.play_circle_fill,
                  size: 60,
                  color: Colors.red.shade400,
                ),
              ),
              const SizedBox(height: 16),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              ),
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
              Icon(Icons.play_circle_outline,
                  size: 64, color: Colors.white.withOpacity(0.5)),
              const SizedBox(height: 12),
              Text('Нет шортсов',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.7), fontSize: 16)),
            ],
          ),
        ),
      );
    }

    final short = _shorts[_currentIndex];
    final isLiked = _likedMap[short.id] ?? false;
    final padding = MediaQuery.of(context).padding;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // === PAGE VIEW ===
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: _shorts.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
              _playVideo(index);
              if (index >= _shorts.length - 3) _loadMore();
            },
            itemBuilder: (context, index) {
              final s = _shorts[index];
              final isCurrent = index == _currentIndex;
              return GestureDetector(
                onTapDown: isCurrent ? _handleTap : null,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Video
                    if (isCurrent && _isInitialized && _vpc != null)
                      Center(
                        child: AspectRatio(
                          aspectRatio: _vpc!.value.aspectRatio > 0
                              ? _vpc!.value.aspectRatio
                              : 9 / 16,
                          child: VideoPlayer(_vpc!),
                        ),
                      )
                    else if (isCurrent)
                      _buildSkeleton(s)
                    else
                      CachedNetworkImage(
                        imageUrl: s.thumbnailUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            Container(color: Colors.black),
                      ),
                  ],
                ),
              );
            },
          ),

          // === BOTTOM GRADIENT ===
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              height: 320,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
            ),
          ),

          // === TOP GRADIENT ===
          Positioned(
            left: 0, right: 0, top: 0,
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

          // === TOP BAR ===
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(16, padding.top + 8, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.play_circle, color: Colors.white, size: 24),
                  const SizedBox(width: 8),
                  const Text('Shorts',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const Spacer(),
                  // Mute button
                  GestureDetector(
                    onTap: _toggleMute,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isMuted ? Icons.volume_off : Icons.volume_up,
                        color: Colors.white,
                        size: 18,
                      ),
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

          // === BOTTOM INFO ===
          Positioned(
            left: 12,
            right: 72,
            bottom: padding.bottom + 60,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Channel
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.grey.shade800,
                      backgroundImage: short.avatar.isNotEmpty
                          ? CachedNetworkImageProvider(abs(short.avatar))
                          : null,
                      child: short.avatar.isEmpty
                          ? Text(
                              short.channelName.isNotEmpty
                                  ? short.channelName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.white),
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      short.channelName.isNotEmpty
                          ? short.channelName
                          : short.username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(width: 12),
                    // Subscribe
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Подписаться',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Title
                Text(
                  short.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                // Views
                if (short.views > 0)
                  Text(
                    '${_formatViews(short.views)} просмотров',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 12,
                      shadows: const [
                        Shadow(blurRadius: 3, color: Colors.black54),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // === RIGHT SIDE BUTTONS ===
          Positioned(
            right: 8,
            bottom: padding.bottom + 80,
            child: Column(
              children: [
                // Like
                _actionButton(
                  icon: isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                  label: isLiked ? '' : '',
                  color: isLiked ? const Color(0xFF3EA6FF) : Colors.white,
                  onTap: () async {
                    final auth = Provider.of<AuthProvider>(context, listen: false);
                    if (!auth.isAuth) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Войдите, чтобы ставить лайки')),
                      );
                      return;
                    }
                    try {
                      final api =
                          Provider.of<ApiService>(context, listen: false);
                      await api.reaction(short.id, 'like');
                      setState(() => _likedMap[short.id] = !isLiked);
                    } catch (_) {}
                  },
                ),
                const SizedBox(height: 20),
                // Dislike
                _actionButton(
                  icon: Icons.thumb_down_outlined,
                  label: '',
                  color: Colors.white,
                  onTap: () {},
                ),
                const SizedBox(height: 20),
                // Comments
                _actionButton(
                  icon: Icons.chat_bubble_outline,
                  label: '',
                  color: Colors.white,
                  onTap: () => _showCommentsSheet(short),
                ),
                const SizedBox(height: 20),
                // Share
                _actionButton(
                  icon: Icons.share,
                  label: '',
                  color: Colors.white,
                  onTap: () => Share.share(short.shareUrl),
                ),
                const SizedBox(height: 20),
                // More
                _actionButton(
                  icon: Icons.more_vert,
                  label: '',
                  color: Colors.white,
                  onTap: () => _showMoreSheet(short),
                ),
              ],
            ),
          ),

          // === PROGRESS BAR ===
          Positioned(
            left: 0, right: 0,
            bottom: padding.bottom + 40,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: _progress.clamp(0.0, 1.0),
                        backgroundColor: Colors.white.withOpacity(0.2),
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(Colors.white),
                        minHeight: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // === DOUBLE TAP HEART ===
          if (_showHeart)
            Positioned(
              left: _heartPosition.dx - 36,
              top: _heartPosition.dy - 36,
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
                child: const Icon(
                  Icons.favorite,
                  color: Colors.red,
                  size: 72,
                ),
              ),
            ),

          // === PLAY/PAUSE CENTER ICON ===
          if (_showPlayIcon)
            Center(
              child: AnimatedOpacity(
                opacity: _showPlayIcon ? 0.8 : 0.0,
                duration: const Duration(milliseconds: 150),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.play_arrow : Icons.pause,
                    color: Colors.white,
                    size: 40,
                  ),
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
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2),
            ),
          ),
          errorWidget: (_, __, ___) => Container(
            color: Colors.black,
            child: const Center(
              child: Icon(Icons.error_outline, color: Colors.white54, size: 48),
            ),
          ),
        ),
        // Loading overlay
        if (!_isInitialized)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      color: Colors.white.withOpacity(0.8),
                      strokeWidth: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Загрузка...',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
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
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 10)),
          ],
        ],
      ),
    );
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
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            // Handle
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade600,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text('Комментарии',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const Divider(height: 1),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chat_bubble_outline,
                        size: 48,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 12),
                    Text('Комментарии скоро появятся',
                        style: TextStyle(
                            color:
                                Theme.of(context).textTheme.bodySmall?.color)),
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
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade600,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Поделиться'),
              onTap: () {
                Navigator.pop(ctx);
                Share.share(short.shareUrl);
              },
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
