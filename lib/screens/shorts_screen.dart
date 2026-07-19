import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class ShortsScreen extends StatefulWidget {
  const ShortsScreen({super.key});

  @override
  State<ShortsScreen> createState() => _ShortsScreenState();
}

class _ShortsScreenState extends State<ShortsScreen> {
  List<Short> _shorts = [];
  bool _loading = true;
  String? _error;
  int _currentPage = 1;
  int _lastPage = 1;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _loadShorts();
  }

  Future<void> _loadShorts() async {
    setState(() { _loading = true; _error = null; });
    try {
      final response = await ApiService.instance.shorts(page: _currentPage);
      final shorts = Short.parseFromHtml(response);
      final data = response['data'] ?? {};
      setState(() {
        _shorts = shorts;
        _currentPage = data['current_page'] ?? 1;
        _lastPage = data['last_page'] ?? 1;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _currentPage >= _lastPage) return;
    setState(() { _loadingMore = true; });
    try {
      final nextPage = _currentPage + 1;
      final response = await ApiService.instance.shorts(page: nextPage);
      final moreShorts = Short.parseFromHtml(response);
      final data = response['data'] ?? {};
      setState(() {
        _shorts.addAll(moreShorts);
        _currentPage = data['current_page'] ?? nextPage;
        _lastPage = data['last_page'] ?? _lastPage;
        _loadingMore = false;
      });
    } catch (e) {
      setState(() { _loadingMore = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Color(0xFFE53935))));
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, color: Color(0xFFE53935), size: 48),
            const SizedBox(height: 12),
            Text('Ошибка: $_error', style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadShorts, child: const Text('Повторить')),
          ]),
        ),
      );
    }
    if (_shorts.isEmpty) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: Text('Нет shorts', style: TextStyle(color: Colors.white54))));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        itemCount: _shorts.length,
        itemBuilder: (context, index) {
          // Auto-load more when near end
          if (index >= _shorts.length - 3) {
            _loadMore();
          }
          return ShortsPlayer(short: _shorts[index]);
        },
      ),
    );
  }
}

class ShortsPlayer extends StatefulWidget {
  final Short short;
  const ShortsPlayer({super.key, required this.short});

  @override
  State<ShortsPlayer> createState() => _ShortsPlayerState();
}

class _ShortsPlayerState extends State<ShortsPlayer> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  bool _isPlaying = false;
  bool _showControls = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.short.videoUrl));
      await _videoController.initialize();
      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: true,
        looping: true,
        showControls: false,
        allowFullScreen: false,
      );
      if (mounted) {
        setState(() { _isPlaying = true; });
      }
    } catch (e) {
      debugPrint('Shorts player init error: $e');
    }
  }

  @override
  void dispose() {
    _videoController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      if (_videoController.value.isPlaying) {
        _videoController.pause();
        _isPlaying = false;
      } else {
        _videoController.play();
        _isPlaying = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _togglePlayPause();
        setState(() { _showControls = true; });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() { _showControls = false; });
        });
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video
          _chewieController != null
              ? FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: _videoController.value.size.width,
                    height: _videoController.value.size.height,
                    child: Chewie(controller: _chewieController!),
                  ),
                )
              : Container(
                  color: Colors.black,
                  child: const Center(child: CircularProgressIndicator(color: Color(0xFFE53935))),
                ),

          // Play/pause overlay
          if (_showControls)
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),

          // Info overlay at bottom
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.short.title.isNotEmpty)
                  Text(
                    widget.short.title,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (widget.short.username.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '@${widget.short.username}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
                if (widget.short.views > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${widget.short.views} просмотров',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),

          // Right side actions
          Positioned(
            right: 12,
            bottom: MediaQuery.of(context).padding.bottom + 80,
            child: Column(
              children: [
                _actionButton(Icons.favorite_border, '${widget.short.views}', () {}),
                const SizedBox(height: 20),
                _actionButton(Icons.chat_bubble_outline, '', () {}),
                const SizedBox(height: 20),
                _actionButton(Icons.share, '', () {}),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}
