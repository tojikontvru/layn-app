import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
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
  Map<String, String> _cookies = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Извлекает cookies из HTTP-ответа
  void _extractCookies(http.Response response) {
    final raw = response.headers['set-cookie'];
    if (raw == null) return;
    // set-cookie может содержать несколько значений разделённых запятыми
    // но запятая также бывает в value cookie — аккуратно парсим
    final parts = raw.split(RegExp(r',(?=\s*\w+=)'));
    for (final part in parts) {
      final kv = part.split(';')[0].trim().split('=');
      if (kv.length >= 2) {
        _cookies[kv[0].trim()] = kv.sublist(1).join('=').trim();
      }
    }
  }

  String get _cookieHeader =>
      _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await http.get(Uri.parse('$shortsUrl?page=$_page'));
      _extractCookies(r);
      debugPrint('SHORTS cookies: ${_cookies.keys.toList()}');

      if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
      final d = jsonDecode(r.body) as Map<String, dynamic>;
      final shorts = Short.fromResponse(d);
      debugPrint('SHORTS parsed: ${shorts.length} shorts');

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
          return _Player(short: _shorts[i], cookieHeader: _cookieHeader);
        },
      ),
    );
  }

  void _loadMore() async {
    final nextPage = _page + 1;
    try {
      final r = await http.get(Uri.parse('$shortsUrl?page=$nextPage'));
      _extractCookies(r);
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
  final String cookieHeader;
  const _Player({required this.short, required this.cookieHeader});
  @override
  State<_Player> createState() => _PlayerState();
}

class _PlayerState extends State<_Player> {
  VideoPlayerController? _videoCtrl;
  ChewieController? _chewieCtrl;
  bool _ready = false;
  bool _paused = false;
  String? _error;
  double _downloadProgress = 0;
  File? _tempFile;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final originalUrl = abs(widget.short.videoUrl);
    debugPrint('SHORTS player init: $originalUrl');

    try {
      // === Шаг 1: Скачиваем видео через HTTP ===
      setState(() => _downloadProgress = 0);

      final response = await http.get(
        Uri.parse(originalUrl),
        headers: {
          'Accept': 'video/*, application/octet-stream, */*',
          'Referer': 'https://layn.su/',
          'Origin': 'https://layn.su',
          'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36',
          if (widget.cookieHeader.isNotEmpty) 'Cookie': widget.cookieHeader,
        },
      ).timeout(const Duration(seconds: 30));

      debugPrint('SHORTS download status: ${response.statusCode}');
      debugPrint('SHORTS download content-type: ${response.headers['content-type']}');
      debugPrint('SHORTS download content-length: ${response.headers['content-length']}');

      // Логируем redirects
      final reqUrl = response.request?.url.toString() ?? originalUrl;
      if (reqUrl != originalUrl) {
        debugPrint('SHORTS redirected to: $reqUrl');
      }

      if (response.statusCode != 200) {
        // Попробуем второй раз (сервер может требовать cookies)
        debugPrint('SHORTS retrying with different headers...');
        final retry = await http.get(
          Uri.parse(reqUrl),
          headers: {
            'Accept': 'video/mp4, video/webm, */*',
            'User-Agent': 'ExoPlayerLib/2.19.1',
          },
        ).timeout(const Duration(seconds: 30));

        debugPrint('SHORTS retry status: ${retry.statusCode}');
        debugPrint('SHORTS retry content-type: ${retry.headers['content-type']}');

        if (retry.statusCode != 200) {
          throw Exception('HTTP ${response.statusCode} / ${retry.statusCode}');
        }
        // Сохраняем retry результат
        _tempFile = await _saveTempFile(retry.bodyBytes, widget.short.id);
      } else {
        _tempFile = await _saveTempFile(response.bodyBytes, widget.short.id);
      }

      debugPrint('SHORTS saved to: ${_tempFile!.path} (${_tempFile!.lengthSync()} bytes)');

      // Проверяем что файл не пустой и не HTML
      final firstBytes = _tempFile!.readAsBytesSync().take(100).toList();
      final asString = String.fromCharCodes(firstBytes.where((b) => b >= 32 && b < 127));
      debugPrint('SHORTS file header: $asString');

      // === Шаг 2: Воспроизводим локальный файл ===
      _videoCtrl = VideoPlayerController.file(_tempFile!);
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

      setState(() {
        _ready = true;
        _downloadProgress = 0;
      });
    } catch (e) {
      debugPrint('SHORTS player error: $e');
      debugPrint('SHORTS URL: $originalUrl');
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<File> _saveTempFile(List<int> bytes, int id) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/short_$id.mp4');
    await file.writeAsBytes(bytes);
    return file;
  }

  @override
  void dispose() {
    _chewieCtrl?.dispose();
    _videoCtrl?.dispose();
    // Удаляем временный файл
    _tempFile?.deleteSync();
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
          else if (_downloadProgress > 0 && _downloadProgress < 1)
            _buildDownloading()
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

          // Progress bar
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
                  setState(() { _error = null; _ready = false; _downloadProgress = 0; });
                  _chewieCtrl?.dispose();
                  _videoCtrl?.dispose();
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

  Widget _buildDownloading() {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.short.thumbnailUrl.isNotEmpty)
          Image.network(widget.short.thumbnailUrl, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox()),
        Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                value: _downloadProgress > 0 ? _downloadProgress : null,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(Color(0xFF6C5CE7)),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _downloadProgress > 0
                  ? '${(_downloadProgress * 100).toStringAsFixed(0)}%'
                  : 'Загрузка видео...',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ]),
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
