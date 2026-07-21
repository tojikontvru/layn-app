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
  ChewieController? _currentChewie;
  VideoPlayerController? _currentVpc;

  @override
  void initState() {
    super.initState();
    _loadShorts();
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
        _playVideo(0);
      }
    } catch (e) {
      setState(() => _loading = false);
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
      setState(() => _loadingMore = false);
    }
  }

  void _playVideo(int index) async {
    if (index < 0 || index >= _shorts.length) return;
    _currentChewie?.dispose();
    _currentVpc?.dispose();
    
    final short = _shorts[index];
    try {
      final url = abs(short.videoUrl);
      _currentVpc = VideoPlayerController.networkUrl(Uri.parse(url));
      await _currentVpc!.initialize();
      if (!mounted) return;
      _currentChewie = ChewieController(
        videoPlayerController: _currentVpc!,
        autoPlay: true,
        looping: true,
        showControls: false,
        allowFullScreen: false,
        allowMuting: true,
        aspectRatio: 9 / 16,
        placeholder: Container(color: Colors.black),
      );
      WakelockPlus.enable();
      setState(() {});
    } catch (e) {
      debugPrint('Shorts play error: $e');
    }
  }

  @override
  void dispose() {
    _currentChewie?.dispose();
    _currentVpc?.dispose();
    _pageController.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_shorts.isEmpty) {
      return const Center(child: Text('Нет шортсов'));
    }

    return PageView.builder(
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
        return Stack(
          fit: StackFit.expand,
          children: [
            // Video
            if (isCurrent && _currentChewie != null)
              FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: _currentVpc!.value.size.width,
                  height: _currentVpc!.value.size.height,
                  child: Chewie(controller: _currentChewie!),
                ),
              )
            else if (short.thumbnailUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: normalizeUrl(short.thumbnailUrl),
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: Colors.black),
                errorWidget: (_, __, ___) => Container(color: Colors.black),
              )
            else
              Container(color: Colors.black),

            // Gradient overlay (bottom)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 250,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
              ),
            ),

            // Title & channel info
            Positioned(
              left: 16,
              right: 80,
              bottom: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Channel
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundImage: short.avatar.isNotEmpty
                            ? CachedNetworkImageProvider(normalizeUrl(short.avatar))
                            : null,
                        child: short.avatar.isEmpty
                            ? Text(
                                short.channelName.isNotEmpty
                                    ? short.channelName[0].toUpperCase()
                                    : short.username.isNotEmpty
                                        ? short.username[0].toUpperCase()
                                        : '?',
                                style: const TextStyle(fontSize: 12),
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          short.channelName.isNotEmpty ? short.channelName : short.username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
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
              bottom: 100,
              child: Column(
                children: [
                  // Like
                  _shortAction(
                    icon: Icons.thumb_up_outlined,
                    label: '',
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
                      } catch (e) {
                        debugPrint('Like error: $e');
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  // Dislike
                  _shortAction(
                    icon: Icons.thumb_down_outlined,
                    label: '',
                    onTap: () {},
                  ),
                  const SizedBox(height: 16),
                  // Share (YouTube-style)
                  _shortAction(
                    icon: Icons.share,
                    label: 'Поделиться',
                    onTap: () {
                      Share.share(short.shareUrl);
                    },
                  ),
                  const SizedBox(height: 16),
                  // Comments count
                  _shortAction(
                    icon: Icons.comment_outlined,
                    label: '',
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _shortAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 28),
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
