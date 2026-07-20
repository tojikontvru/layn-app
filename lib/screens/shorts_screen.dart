import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../constants.dart';
import '../models/models.dart';

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
    setState(() { _loading = true; _error = null; });
    try {
      final r = await http.get(
        Uri.parse('$shortsUrl?page=$_page'),
        headers: {'Accept': 'application/json'},
      );
      debugPrint('SHORTS API: ${r.statusCode}');

      if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
      final d = jsonDecode(r.body) as Map<String, dynamic>;

      final shorts = Short.fromResponse(d);
      debugPrint('SHORTS parsed: ${shorts.length} shorts');
      for (final s in shorts) {
        debugPrint('  #${s.id}: url="${s.videoUrl}" title="${s.title}"');
      }

      final meta = d['data'] ?? {};
      setState(() {
        _shorts = shorts;
        _page = meta['current_page'] ?? 1;
        _lastPage = meta['last_page'] ?? 1;
        _loading = false;
      });
    } catch (e) {
      debugPrint('SHORTS load error: $e');
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    if (_error != null || _shorts.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
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
          return _Player(short: _shorts[i]);
        },
      ),
    );
  }

  void _loadMore() async {
    final nextPage = _page + 1;
    try {
      final r = await http.get(
        Uri.parse('$shortsUrl?page=$nextPage'),
        headers: {'Accept': 'application/json'},
      );
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
}

class _Player extends StatefulWidget {
  final Short short;
  const _Player({required this.short});
  @override
  State<_Player> createState() => _PlayerState();
}

class _PlayerState extends State<_Player> {
  VideoPlayerController? _videoCtrl;
  ChewieController? _chewieCtrl;
  bool _ready = false;
  bool _paused = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    // API возвращает полные URL: https://layn.su/storage/videos/xxx.mp4
    final url = widget.short.videoUrl;
    debugPrint('SHORTS player init: $url');

    try {
      _videoCtrl = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: const {
          'Accept': '*/*',
          'Referer': 'https://layn.su/',
          'Origin': 'https://layn.su',
        },
      );

      await _videoCtrl!.initialize();

      if (!mounted) return;

      _chewieCtrl = ChewieController(
        videoPlayerController: _videoCtrl!,
        autoPlay: true,
        looping: true,
        showControls: false,
        showControlsOnInitialize: false,
        allowFullScreen: false,
        allowMuting: false,
        aspectRatio: _videoCtrl!.value.aspectRatio,
      );

      setState(() => _ready = true);
    } catch (e) {
      debugPrint('SHORTS player error: $e');
      debugPrint('SHORTS URL: $url');
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_error != null)
            _buildError()
          else if (_ready && _chewieCtrl != null)
            FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: _videoCtrl!.value.size.width,
                height: _videoCtrl!.value.size.height,
                child: Chewie(controller: _chewieCtrl!),
              ),
            )
          else
            _buildLoading(),

          if (_paused)
            const Center(
              child: Icon(Icons.pause_circle_outline, color: Colors.white70, size: 72),
            ),

          // Info overlay
          Positioned(
            left: 16,
            right: 60,
            bottom: MediaQuery.of(context).padding.bottom + 24,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (widget.short.username.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('@${widget.short.username}',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              if (widget.short.title.isNotEmpty)
                Text(widget.short.title,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                    maxLines: 3, overflow: TextOverflow.ellipsis),
              if (widget.short.views > 0) ...[
                const SizedBox(height: 6),
                Text('${widget.short.views} просмотров',
                    style: const TextStyle(color: Colors.white60, fontSize: 13)),
              ],
            ]),
          ),

          // Right buttons
          Positioned(
            right: 12,
            bottom: MediaQuery.of(context).padding.bottom + 100,
            child: Column(children: [
              _avatar(),
              const SizedBox(height: 20),
              _btn(Icons.favorite_border, ''),
              const SizedBox(height: 20),
              _btn(Icons.chat_bubble_outline, ''),
              const SizedBox(height: 20),
              _btn(Icons.share, ''),
            ]),
          ),

          // Progress
          if (_ready)
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: VideoProgressIndicator(
                _videoCtrl!,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: Color(0xFF6C5CE7),
                  bufferedColor: Colors.white24,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _avatar() {
    final hasAvatar = widget.short.avatar.isNotEmpty;
    return Column(children: [
      CircleAvatar(
        radius: 22,
        backgroundColor: const Color(0xFF333),
        backgroundImage: hasAvatar ? NetworkImage(widget.short.avatar) : null,
        child: !hasAvatar
            ? Text((widget.short.username.isNotEmpty ? widget.short.username[0] : '?').toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))
            : null,
      ),
      const SizedBox(height: 4),
      const Icon(Icons.add_circle_outline, color: Colors.white, size: 18),
    ]);
  }

  Widget _buildError() {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.short.thumbnailUrl.isNotEmpty)
          Image.network(widget.short.thumbnailUrl, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox()),
        Container(
          color: Colors.black54,
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              const Text('Ошибка загрузки видео',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(widget.short.videoUrl,
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                    maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () {
                  setState(() { _error = null; _ready = false; });
                  _videoCtrl?.dispose();
                  _chewieCtrl?.dispose();
                  _initPlayer();
                },
                child: const Text('Повторить'),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildLoading() {
    if (widget.short.thumbnailUrl.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.network(widget.short.thumbnailUrl, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox()),
          const Center(child: CircularProgressIndicator(color: Colors.white)),
        ],
      );
    }
    return const Center(child: CircularProgressIndicator(color: Colors.white));
  }

  Widget _btn(IconData icon, String label) => Column(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(color: Colors.white12, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ]);
}
