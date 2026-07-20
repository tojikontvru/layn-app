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
      final r = await http.get(Uri.parse('$shortsUrl?page=$_page'));
      debugPrint('SHORTS API response: ${r.statusCode}, ${r.body.length} bytes');
      if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
      final d = jsonDecode(r.body) as Map<String, dynamic>;

      debugPrint('SHORTS data keys: ${(d['data'] as Map?)?.keys?.toList()}');
      final videos = d['data']?['videos'];
      if (videos is String) {
        debugPrint('SHORTS videos is HTML: ${videos.length} chars');
      } else if (videos is List) {
        debugPrint('SHORTS videos is JSON: ${videos.length} items');
        if (videos.isNotEmpty) {
          debugPrint('SHORTS first item keys: ${(videos[0] as Map).keys.toList()}');
          debugPrint('SHORTS first item: ${videos[0]}');
        }
      }

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
      final r = await http.get(Uri.parse('$shortsUrl?page=$nextPage'));
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
  String? _resolvedUrl;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  /// Резолвит URL через HTTP — следует редиректам, возвращает финальный URL
  Future<String> _resolveUrl(String url) async {
    debugPrint('SHORTS resolving URL: $url');
    try {
      // Делаем HEAD запрос чтобы получить финальный URL после редиректов
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': '*/*',
          'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36',
        },
      ).timeout(const Duration(seconds: 10));

      debugPrint('SHORTS resolve: status=${response.statusCode} url=${response.request?.url}');
      debugPrint('SHORTS resolve: content-type=${response.headers['content-type']}');
      debugPrint('SHORTS resolve: content-length=${response.headers['content-length']}');

      // Если редирект — вернём финальный URL
      final finalUrl = response.request?.url.toString() ?? url;
      debugPrint('SHORTS resolved URL: $finalUrl');
      return finalUrl;
    } catch (e) {
      debugPrint('SHORTS resolve error: $e, using original URL');
      return url;
    }
  }

  Future<void> _initPlayer() async {
    final originalUrl = abs(widget.short.videoUrl);
    debugPrint('SHORTS player init original: $originalUrl');

    try {
      // Шаг 1: Резолвим URL (следуем редиректам)
      _resolvedUrl = await _resolveUrl(originalUrl);
      debugPrint('SHORTS player init resolved: $_resolvedUrl');

      // Шаг 2: Загружаем видео с финальным URL
      _videoCtrl = VideoPlayerController.networkUrl(
        Uri.parse(_resolvedUrl!),
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
      debugPrint('SHORTS original URL: $originalUrl');
      debugPrint('SHORTS resolved URL: $_resolvedUrl');
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

          Positioned(
            left: 16,
            right: 60,
            bottom: MediaQuery.of(context).padding.bottom + 24,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (widget.short.title.isNotEmpty)
                Text(widget.short.title,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              if (widget.short.views > 0) ...[
                const SizedBox(height: 6),
                Text('${widget.short.views} просмотров',
                    style: const TextStyle(color: Colors.white60, fontSize: 13)),
              ],
            ]),
          ),

          Positioned(
            right: 12,
            bottom: MediaQuery.of(context).padding.bottom + 100,
            child: Column(children: [
              _btn(Icons.favorite_border, '${widget.short.views}'),
              const SizedBox(height: 24),
              _btn(Icons.chat_bubble_outline, ''),
              const SizedBox(height: 24),
              _btn(Icons.share, ''),
            ]),
          ),

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

  Widget _buildError() {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.short.thumbnailUrl.isNotEmpty)
          Image.network(
            widget.short.thumbnailUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox(),
          ),
        Container(
          color: Colors.black54,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 12),
                const Text('Ошибка загрузки видео',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(_resolvedUrl ?? widget.short.videoUrl,
                      style: const TextStyle(color: Colors.white38, fontSize: 10),
                      maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: () {
                    setState(() { _error = null; _ready = false; _resolvedUrl = null; });
                    _videoCtrl?.dispose();
                    _chewieCtrl?.dispose();
                    _initPlayer();
                  },
                  child: const Text('Повторить'),
                ),
              ],
            ),
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
