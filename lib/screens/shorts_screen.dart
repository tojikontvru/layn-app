import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
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
      if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
      final d = jsonDecode(r.body) as Map<String, dynamic>;
      final shorts = Short.fromResponse(d);
      final meta = d['data'] ?? {};
      setState(() {
        _shorts = shorts;
        _page = meta['current_page'] ?? 1;
        _lastPage = meta['last_page'] ?? 1;
        _loading = false;
      });
    } catch (e) {
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
  late VideoPlayerController _ctrl;
  bool _ready = false;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.short.videoUrl))
      ..initialize().then((_) {
        if (mounted) { setState(() => _ready = true); _ctrl.play(); }
      }).catchError((_) {});
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _paused ? _ctrl.play() : _ctrl.pause();
      _paused = !_paused;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _ready
              ? FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: _ctrl.value.size.width,
                    height: _ctrl.value.size.height,
                    child: VideoPlayer(_ctrl),
                  ),
                )
              : const Center(child: CircularProgressIndicator(color: Colors.white)),
          if (_paused)
            const Center(child: Icon(Icons.pause_circle_outline, color: Colors.white70, size: 72)),
          // Info
          Positioned(
            left: 16, right: 60,
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
          // Right buttons
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
          // Progress
          if (_ready)
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: VideoProgressIndicator(_ctrl, allowScrubbing: true,
                  colors: const VideoProgressColors(playedColor: Color(0xFF6C5CE7), bufferedColor: Colors.white24)),
            ),
        ],
      ),
    );
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
