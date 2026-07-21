import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
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

  // Per-page controllers
  final Map<int, VideoPlayerController> _vpcs = {};
  final Map<int, ChewieController> _chewies = {};
  final Map<int, bool> _likedMap = {};

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _loadShorts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WakelockPlus.enable();
  }

  Future<void> _loadShorts() async {
    setState(() => _loading = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final data = await api.shorts(page: _currentPage);
      final newShorts = Short.fromResponse({'data': {'shorts': data}});
      setState(() {
        _shorts.addAll(newShorts);
        _loading = false;
        if (newShorts.isEmpty) _hasMore = false;
      });
      if (_shorts.isNotEmpty && _currentPage == 1) {
        _initPageVideo(0);
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
      setState(() {
        _shorts.addAll(newShorts);
        _loadingMore = false;
        if (newShorts.isEmpty) _hasMore = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _initPageVideo(int index) async {
    if (index < 0 || index >= _shorts.length) return;

    // Dispose previous
    _disposeVideo(index - 1);

    if (_vpcs.containsKey(index)) {
      // Already initialized, just play
      await _vpcs[index]!.play();
      if (mounted) setState(() {});
      return;
    }

    final short = _shorts[index];
    try {
      final url = abs(short.videoUrl);
      if (url.isEmpty) return;
      final vpc = VideoPlayerController.networkUrl(Uri.parse(url));
      _vpcs[index] = vpc;
      await vpc.initialize();
      if (!mounted || _disposed) return;

      final cc = ChewieController(
        videoPlayerController: vpc,
        autoPlay: true,
        looping: false,
        showControls: false,
        allowFullScreen: false,
        allowMuting: true,
        aspectRatio: vpc.value.aspectRatio > 0 ? vpc.value.aspectRatio : 9 / 16,
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.white,
          handleColor: Colors.white,
          bufferedColor: Colors.white30,
        ),
        placeholder: Container(color: Colors.black),
        errorBuilder: (_, msg) => Container(
          color: Colors.black,
          child: const Center(
            child: Icon(Icons.error_outline, color: Colors.red, size: 48),
          ),
        ),
      );
      _chewies[index] = cc;
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Shorts play error index=$index: $e');
    }
  }

  void _disposeVideo(int index) {
    if (index < 0 || index >= _shorts.length) return;
    _chewies[index]?.dispose();
    _chewies.remove(index);
    _vpcs[index]?.dispose();
    _vpcs.remove(index);
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    for (final cc in _chewies.values) {
      cc.dispose();
    }
    for (final vpc in _vpcs.values) {
      vpc.dispose();
    }
    _chewies.clear();
    _vpcs.clear();
    _pageController.dispose();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_shorts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_circle_outline,
                size: 64,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            const Text('Нет шортсов',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: _shorts.length,
        onPageChanged: (index) {
          // Pause previous
          _chewies[_currentIndex]?.videoPlayerController.pause();
          setState(() => _currentIndex = index);
          // Dispose videos far from current (keep ±1)
          for (int i = 0; i < _shorts.length; i++) {
            if ((i - index).abs() > 1) _disposeVideo(i);
          }
          // Init current
          _initPageVideo(index);
          // Preload next
          if (index + 1 < _shorts.length) _initPageVideo(index + 1);
          // Load more
          if (index >= _shorts.length - 3) _loadMore();
        },
        itemBuilder: (context, index) {
          final short = _shorts[index];
          final isCurrent = index == _currentIndex;
          final chewie = _chewies[index];
          final isLiked = _likedMap[short.id] ?? false;

          return Stack(
            fit: StackFit.expand,
            children: [
              // Video or thumbnail
              if (isCurrent && chewie != null)
                GestureDetector(
                  onTap: () {
                    final cc = chewie;
                    if (cc.videoPlayerController.value.isPlaying) {
                      cc.videoPlayerController.pause();
                    } else {
                      cc.videoPlayerController.play();
                    }
                  },
                  child: FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: _vpcs[index]!.value.size.width,
                      height: _vpcs[index]!.value.size.height,
                      child: Chewie(controller: chewie),
                    ),
                  ),
                )
              else if (short.thumbnailUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: short.thumbnailUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: Colors.black),
                  errorWidget: (_, __, ___) => Container(color: Colors.black),
                )
              else
                Container(
                  color: Colors.black,
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),

              // Gradient overlay (bottom)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
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

              // Gradient overlay (top)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: Container(
                  height: 80,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.transparent, Colors.black54],
                    ),
                  ),
                ),
              ),

              // Title & channel info (bottom left)
              Positioned(
                left: 16,
                right: 80,
                bottom: 100,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Channel
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
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
                                      fontSize: 12, color: Colors.white),
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            short.channelName.isNotEmpty
                                ? short.channelName
                                : short.username,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Title
                    Text(
                      short.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // Views
                    if (short.views > 0)
                      Text(
                        '${short.views} просмотров',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),

              // Right side action buttons (YouTube Shorts style)
              Positioned(
                right: 8,
                bottom: 120,
                child: Column(
                  children: [
                    // Like
                    _shortAction(
                      icon: isLiked
                          ? Icons.thumb_up
                          : Icons.thumb_up_outlined,
                      label: '',
                      color: isLiked
                          ? Theme.of(context).colorScheme.primary
                          : Colors.white,
                      onTap: () async {
                        final auth =
                            Provider.of<AuthProvider>(context, listen: false);
                        if (!auth.isAuth) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Войдите, чтобы ставить лайки')),
                          );
                          return;
                        }
                        try {
                          final api =
                              Provider.of<ApiService>(context, listen: false);
                          await api.reaction(short.id, 'like');
                          setState(() {
                            _likedMap[short.id] = !isLiked;
                          });
                        } catch (_) {}
                      },
                    ),
                    const SizedBox(height: 20),
                    // Dislike
                    _shortAction(
                      icon: Icons.thumb_down_outlined,
                      label: '',
                      color: Colors.white,
                      onTap: () {},
                    ),
                    const SizedBox(height: 20),
                    // Comments
                    _shortAction(
                      icon: Icons.comment_outlined,
                      label: '',
                      color: Colors.white,
                      onTap: () {},
                    ),
                    const SizedBox(height: 20),
                    // Share
                    _shortAction(
                      icon: Icons.share,
                      label: '',
                      color: Colors.white,
                      onTap: () => Share.share(short.shareUrl),
                    ),
                    const SizedBox(height: 20),
                    // More
                    _shortAction(
                      icon: Icons.more_vert,
                      label: '',
                      color: Colors.white,
                      onTap: () => _showMoreSheet(short),
                    ),
                  ],
                ),
              ),

              // Play/Pause indicator (center)
              if (isCurrent && chewie != null)
                Center(
                  child: AnimatedOpacity(
                    opacity: chewie.videoPlayerController.value.isPlaying
                        ? 0.0
                        : 0.7,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(16),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
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
          ],
        ),
      ),
    );
  }

  Widget _shortAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}
