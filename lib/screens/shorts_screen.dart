import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:provider/provider.dart';
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

  // Active video
  VideoPlayerController? _vpc;
  bool _isPlaying = false;
  bool _isInitialized = false;
  bool _showPlayIcon = false;
  Timer? _hidePlayTimer;

  // Likes
  final Map<int, bool> _likedMap = {};

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

    // Dispose old
    _vpc?.dispose();

    final short = _shorts[index];
    final url = abs(short.videoUrl);
    if (url.isEmpty) return;

    setState(() {
      _isInitialized = false;
      _isPlaying = false;
    });

    try {
      _vpc = VideoPlayerController.networkUrl(Uri.parse(url));
      await _vpc!.initialize();
      if (!mounted) return;

      _vpc!.setLooping(true);
      await _vpc!.play();

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

  @override
  void dispose() {
    _hidePlayTimer?.cancel();
    _vpc?.dispose();
    _pageController.dispose();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
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

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full screen page view
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
              final short = _shorts[index];
              final isCurrent = index == _currentIndex;
              final isLiked = _likedMap[short.id] ?? false;

              return GestureDetector(
                onTap: _togglePlayPause,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // VIDEO
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
                      // Loading state
                      CachedNetworkImage(
                        imageUrl: short.thumbnailUrl.isNotEmpty
                            ? short.thumbnailUrl
                            : '',
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: Colors.black,
                          child: const Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: Colors.black,
                          child: const Center(
                            child: Icon(Icons.error, color: Colors.white54, size: 48),
                          ),
                        ),
                      )
                    else
                      CachedNetworkImage(
                        imageUrl: short.thumbnailUrl.isNotEmpty
                            ? short.thumbnailUrl
                            : '',
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(color: Colors.black),
                      ),

                    // Play/Pause icon overlay (center)
                    if (_showPlayIcon)
                      Center(
                        child: AnimatedOpacity(
                          opacity: _showPlayIcon ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isPlaying ? Icons.play_arrow : Icons.pause,
                              color: Colors.white,
                              size: 48,
                            ),
                          ),
                        ),
                      ),

                    // === BOTTOM GRADIENT ===
                    Positioned(
                      left: 0, right: 0, bottom: 0,
                      child: Container(
                        height: 300,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black87],
                          ),
                        ),
                      ),
                    ),

                    // === BOTTOM INFO (like YouTube Shorts) ===
                    Positioned(
                      left: 12,
                      right: 72,
                      bottom: MediaQuery.of(context).padding.bottom + 60,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Channel name
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
                                            : short.username.isNotEmpty
                                                ? short.username[0].toUpperCase()
                                                : '?',
                                        style: const TextStyle(
                                            fontSize: 11, color: Colors.white),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  short.channelName.isNotEmpty
                                      ? short.channelName
                                      : short.username,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    shadows: [
                                      Shadow(blurRadius: 4, color: Colors.black54),
                                    ],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Title
                          Text(
                            short.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                              shadows: [
                                Shadow(blurRadius: 4, color: Colors.black54),
                              ],
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

                    // === RIGHT SIDE BUTTONS (YouTube Shorts style) ===
                    Positioned(
                      right: 8,
                      bottom: MediaQuery.of(context).padding.bottom + 80,
                      child: Column(
                        children: [
                          // Like
                          _actionButton(
                            icon: isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                            color: isLiked ? const Color(0xFF3EA6FF) : Colors.white,
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
                                setState(() {
                                  _likedMap[short.id] = !(isLiked);
                                });
                              } catch (_) {}
                            },
                          ),
                          const SizedBox(height: 20),

                          // Dislike
                          _actionButton(
                            icon: Icons.thumb_down_outlined,
                            color: Colors.white,
                            onTap: () {},
                          ),
                          const SizedBox(height: 20),

                          // Comments
                          _actionButton(
                            icon: Icons.chat_bubble_outline,
                            color: Colors.white,
                            onTap: () {},
                          ),
                          const SizedBox(height: 20),

                          // Share
                          _actionButton(
                            icon: Icons.share,
                            color: Colors.white,
                            onTap: () => Share.share(short.shareUrl),
                          ),
                          const SizedBox(height: 20),

                          // More
                          _actionButton(
                            icon: Icons.more_vert,
                            color: Colors.white,
                            onTap: () => _showMoreSheet(short),
                          ),
                        ],
                      ),
                    ),

                    // === TOP RIGHT - Channel avatar (small, for navigation) ===
                    Positioned(
                      right: 12,
                      bottom: MediaQuery.of(context).padding.bottom + 310,
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.grey.shade800,
                            backgroundImage: short.avatar.isNotEmpty
                                ? CachedNetworkImageProvider(abs(short.avatar))
                                : null,
                            child: short.avatar.isEmpty
                                ? Text(
                                    short.channelName.isNotEmpty
                                        ? short.channelName[0].toUpperCase()
                                        : short.username.isNotEmpty
                                            ? short.username[0].toUpperCase()
                                            : '?',
                                    style: const TextStyle(
                                        fontSize: 14, color: Colors.white),
                                  )
                                : null,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(Icons.add, color: Colors.white, size: 16),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // === TOP BAR (YouTube Shorts style) ===
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  16, MediaQuery.of(context).padding.top + 8, 16, 8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.transparent, Colors.black54],
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.play_circle,
                      color: Colors.white,
                      size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    'Shorts',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.search, color: Colors.white),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
        ],
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
              width: 40,
              height: 4,
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
