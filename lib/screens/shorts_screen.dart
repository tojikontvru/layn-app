import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:share_plus/share_plus.dart';
import '../constants.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'package:provider/provider.dart';

class ShortsScreen extends StatefulWidget {
  const ShortsScreen({super.key});
  @override
  State<ShortsScreen> createState() => _ShortsScreenState();
}

class _ShortsScreenState extends State<ShortsScreen> {
  List<Short> _shorts = [];
  bool _loading = true;
  String? _error;
  int _page = 1;
  int _lastPage = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await http.get(
        Uri.parse('$shortsUrl?page=$_page'),
        headers: {'Accept': 'application/json'},
      );
      if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
      final d = jsonDecode(r.body) as Map<String, dynamic>;
      final shorts = Short.fromResponse(d);
      final meta = d['data'] ?? {};
      if (mounted) {
        setState(() {
          _shorts = shorts;
          _page = meta['current_page'] ?? 1;
          _lastPage = meta['last_page'] ?? 1;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _loadMore() async {
    final nextPage = _page + 1;
    try {
      final r = await http.get(Uri.parse('$shortsUrl?page=$nextPage'),
          headers: {'Accept': 'application/json'});
      if (r.statusCode != 200) return;
      final d = jsonDecode(r.body) as Map<String, dynamic>;
      final more = Short.fromResponse(d);
      final meta = d['data'] ?? {};
      if (mounted) {
        setState(() {
          _shorts.addAll(more);
          _page = meta['current_page'] ?? nextPage;
          _lastPage = meta['last_page'] ?? _lastPage;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(backgroundColor: Colors.black,
          body: Center(child: CircularProgressIndicator(color: Colors.white)));
    }
    if (_error != null || _shorts.isEmpty) {
      return Scaffold(backgroundColor: Colors.black,
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.video_library_outlined, color: Colors.white24, size: 64),
          const SizedBox(height: 16),
          Text(_error ?? 'Нет shorts', style: const TextStyle(color: Colors.white54)),
          const SizedBox(height: 16),
          FilledButton(onPressed: _load, child: const Text('Повторить')),
        ])),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        itemCount: _shorts.length,
        itemBuilder: (_, i) {
          if (i >= _shorts.length - 3 && _page < _lastPage) _loadMore();
          return ShortPlayer(short: _shorts[i]);
        },
      ),
    );
  }
}

class ShortPlayer extends StatefulWidget {
  final Short short;
  const ShortPlayer({super.key, required this.short});
  @override
  State<ShortPlayer> createState() => _ShortPlayerState();
}

class _ShortPlayerState extends State<ShortPlayer> {
  VideoPlayerController? _videoCtrl;
  ChewieController? _chewieCtrl;
  bool _ready = false;
  bool _paused = false;
  String? _error;
  bool _liked = false;
  int _likeCount = 0;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.short.views;
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final url = widget.short.videoUrl;
    try {
      _videoCtrl = VideoPlayerController.networkUrl(Uri.parse(url),
          httpHeaders: const {'Referer': 'https://layn.su/', 'Origin': 'https://layn.su'});
      await _videoCtrl!.initialize();
      if (!mounted) return;
      _chewieCtrl = ChewieController(
        videoPlayerController: _videoCtrl!,
        autoPlay: true, looping: true,
        showControls: false, showControlsOnInitialize: false,
        allowFullScreen: false, allowMuting: false,
        aspectRatio: _videoCtrl!.value.aspectRatio,
      );
      setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _chewieCtrl?.dispose();
    _videoCtrl?.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_chewieCtrl == null) return;
    setState(() {
      _paused = !_paused;
      _paused ? _chewieCtrl!.pause() : _chewieCtrl!.play();
    });
  }

  void _onLike() async {
    final auth = context.read<AuthProvider>();
    if (!auth.loggedIn) { _showLoginPrompt(); return; }
    setState(() {
      _liked = !_liked;
      _likeCount += _liked ? 1 : -1;
    });
    try { await ApiService.instance.reaction(widget.short.id, 'like'); } catch (_) {}
  }

  void _onShare() {
    Share.share('${widget.short.title}\nhttps://layn.su/play/${widget.short.id}/shorts');
  }

  void _showLoginPrompt() {
    showModalBottomSheet(context: context, backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.person_outline, color: Colors.white, size: 48),
          const SizedBox(height: 16),
          const Text('Войдите чтобы ставить лайки',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6C5CE7)),
            onPressed: () { Navigator.pop(context); },
            child: const Text('Войти'),
          )),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video
          if (_error != null)
            _buildError()
          else if (_ready && _chewieCtrl != null)
            Center(child: AspectRatio(
              aspectRatio: _videoCtrl!.value.aspectRatio,
              child: Chewie(controller: _chewieCtrl!),
            ))
          else
            _buildLoading(),

          // Pause icon
          if (_paused)
            const Center(child: Icon(Icons.play_arrow, color: Colors.white70, size: 80)),

          // Bottom gradient + info
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 40, 80, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter, end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  CircleAvatar(
                    radius: 16, backgroundColor: const Color(0xFF333),
                    backgroundImage: widget.short.avatar.isNotEmpty
                        ? NetworkImage(widget.short.avatar) : null,
                    child: widget.short.avatar.isEmpty
                        ? Text((widget.short.username.isNotEmpty ? widget.short.username[0] : '?').toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 14))
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text('@${widget.short.username}',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white54),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Подписаться', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ]),
                const SizedBox(height: 10),
                if (widget.short.title.isNotEmpty)
                  Text(widget.short.title,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.music_note, color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Expanded(child: Text('@${widget.short.username}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      overflow: TextOverflow.ellipsis)),
                ]),
              ]),
            ),
          ),

          // Right side buttons
          Positioned(
            right: 8,
            bottom: MediaQuery.of(context).padding.bottom + 80,
            child: Column(children: [
              _sideButton(
                icon: _liked ? Icons.favorite : Icons.favorite_border,
                color: _liked ? Colors.red : Colors.white,
                label: _formatCount(_likeCount),
                onTap: _onLike,
              ),
              const SizedBox(height: 20),
              _sideButton(icon: Icons.chat_bubble_outline, label: '', onTap: () {}),
              const SizedBox(height: 20),
              _sideButton(icon: Icons.reply, label: '', onTap: _onShare),
              const SizedBox(height: 20),
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white30),
                ),
                child: const Icon(Icons.music_note, color: Colors.white, size: 18),
              ),
            ]),
          ),

          // Progress
          if (_ready)
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: VideoProgressIndicator(
                _videoCtrl!, allowScrubbing: false,
                colors: const VideoProgressColors(playedColor: Colors.red, bufferedColor: Colors.white24),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sideButton({required IconData icon, Color? color, String? label, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Icon(icon, color: color ?? Colors.white, size: 28),
        if (label != null && label.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
        ],
      ]),
    );
  }

  String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  Widget _buildError() {
    return Stack(fit: StackFit.expand, children: [
      if (widget.short.thumbnailUrl.isNotEmpty)
        Image.network(widget.short.thumbnailUrl, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox()),
      Container(color: Colors.black54,
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 12),
          const Text('Ошибка загрузки', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          FilledButton.tonal(onPressed: () {
            setState(() { _error = null; _ready = false; });
            _videoCtrl?.dispose();
            _chewieCtrl?.dispose();
            _initPlayer();
          }, child: const Text('Повторить')),
        ])),
      ),
    ]);
  }

  Widget _buildLoading() {
    if (widget.short.thumbnailUrl.isNotEmpty) {
      return Stack(fit: StackFit.expand, children: [
        Image.network(widget.short.thumbnailUrl, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox()),
        const Center(child: CircularProgressIndicator(color: Colors.white)),
      ]);
    }
    return const Center(child: CircularProgressIndicator(color: Colors.white));
  }
}
