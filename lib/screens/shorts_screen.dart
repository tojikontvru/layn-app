import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class ShortsScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const ShortsScreen({super.key, this.onBack});
  @override
  State<ShortsScreen> createState() => _ShortsScreenState();
}

class _ShortsScreenState extends State<ShortsScreen> {
  List<Video> _shorts = [];
  bool _loading = true;
  String? _error;
  final PageController _pageCtrl = PageController();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = context.read<ApiService>();
      final shorts = await api.shorts();
      if (mounted) {
        setState(() {
          _shorts = shorts.where((v) => v.videoUrl.isNotEmpty && v.videoUrl != 'None').toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(color: Colors.black, child: const Center(child: CircularProgressIndicator(color: Color(0xFFE53935))));
    }
    if (_error != null) {
      return Container(color: Colors.black, child: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
          const SizedBox(height: 12),
          Text('Ошибка загрузки', style: TextStyle(color: Colors.grey[400], fontSize: 16)),
          const SizedBox(height: 16),
          ElevatedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Повторить'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935))),
        ]),
      ));
    }
    if (_shorts.isEmpty) {
      return Container(color: Colors.black, child: const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.short_text, size: 64, color: Colors.grey),
          SizedBox(height: 12),
          Text('Shorts пока нет', style: TextStyle(color: Colors.grey, fontSize: 16)),
        ]),
      ));
    }
    return Container(
      color: Colors.black,
      child: PageView.builder(
        controller: _pageCtrl,
        scrollDirection: Axis.vertical,
        physics: const PageScrollPhysics(),
        itemCount: _shorts.length,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemBuilder: (context, index) => _ShortsItem(
          video: _shorts[index],
          isActive: index == _currentIndex,
          onBack: widget.onBack,
        ),
      ),
    );
  }
}

class _ShortsItem extends StatefulWidget {
  final Video video;
  final bool isActive;
  final VoidCallback? onBack;
  const _ShortsItem({required this.video, required this.isActive, this.onBack});
  @override
  State<_ShortsItem> createState() => _ShortsItemState();
}

class _ShortsItemState extends State<_ShortsItem> {
  VideoPlayerController? _vp;
  ChewieController? _chewie;
  bool _playerReady = false;
  bool _showPauseIcon = false;
  bool _initialized = false;
  int _likeCount = 0;
  bool _isLiked = false;
  final _commentCtrl = TextEditingController();
  List<Comment> _comments = [];
  bool _showComments = false;
  bool _loadingComments = false;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      _initPlayer();
      WakelockPlus.enable();
    }
  }

  @override
  void didUpdateWidget(covariant _ShortsItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      if (!_initialized) _initPlayer();
      else if (_playerReady && _vp != null && !_vp!.value.isPlaying) {
        _vp!.play();
        WakelockPlus.enable();
      }
      setState(() => _showPauseIcon = false);
    }
    if (!widget.isActive && oldWidget.isActive) {
      if (_playerReady && _vp != null && _vp!.value.isPlaying) _vp!.pause();
      setState(() => _showPauseIcon = false);
      WakelockPlus.disable();
    }
  }

  void _initPlayer() {
    final url = widget.video.videoUrl;
    if (url.isEmpty || url == 'None' || _initialized) return;
    _initialized = true;
    _vp = VideoPlayerController.networkUrl(Uri.parse(url), httpHeaders: const {'Connection': 'keep-alive'});
    _vp!.initialize().then((_) {
      if (!mounted) return;
      _chewie = ChewieController(videoPlayerController: _vp!, autoPlay: true, looping: true, allowFullScreen: false, allowMuting: false, showControls: false);
      setState(() => _playerReady = true);
    }).catchError((_) {
      Future.delayed(const Duration(seconds: 2), () { if (mounted) _retryInit(); });
    });
    _vp!.addListener(() {
      if (!mounted) return;
      if (_vp!.value.errorDescription != null && _playerReady) {
        Future.delayed(const Duration(seconds: 3), () { if (mounted) _retryInit(); });
      }
    });
  }

  void _retryInit() {
    _initialized = false;
    _playerReady = false;
    _vp?.dispose();
    _chewie?.dispose();
    _vp = null;
    _chewie = null;
    _initPlayer();
  }

  void _onTapPlay() {
    if (_vp == null || !_playerReady) {
      _initPlayer();
      return;
    }
    if (_vp!.value.isPlaying) {
      _vp!.pause();
      WakelockPlus.disable();
      setState(() => _showPauseIcon = true);
    } else {
      _vp!.play();
      WakelockPlus.enable();
      setState(() => _showPauseIcon = false);
    }
  }

  void _toggleLike() {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuth) { Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())); return; }
    setState(() { _isLiked = !_isLiked; _likeCount += _isLiked ? 1 : -1; });
  }

  Future<void> _loadComments() async {
    setState(() { _showComments = true; _loadingComments = true; });
    try { _comments = await context.read<ApiService>().comments(widget.video.id); } catch (_) {}
    if (mounted) setState(() => _loadingComments = false);
  }

  Future<void> _sendComment() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuth) { Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())); return; }
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    try { await context.read<ApiService>().comment(widget.video.id, text); _commentCtrl.clear(); await _loadComments(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
  }

  @override
  void dispose() {
    _vp?.dispose();
    _chewie?.dispose();
    _commentCtrl.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.video;
    final auth = context.watch<AuthProvider>();
    final size = MediaQuery.of(context).size;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final topPad = MediaQuery.of(context).padding.top;

    return Stack(fit: StackFit.expand, children: [
      // Video layer
      Container(color: Colors.black, child: Stack(fit: StackFit.expand, children: [
        if (v.thumb.isNotEmpty) CachedNetworkImage(imageUrl: v.thumb, fit: BoxFit.cover),
        if (_playerReady && _chewie != null) Center(child: AspectRatio(aspectRatio: _vp!.value.aspectRatio, child: Chewie(controller: _chewie!))),
      ])),
      // Tap overlay
      Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: _onTapPlay)),
      // Play/Pause icon
      if (!_playerReady || _showPauseIcon)
        Center(child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), shape: BoxShape.circle),
          child: Icon(_showPauseIcon ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 48))),
      // Loading
      if (_initialized && !_playerReady) const Center(child: CircularProgressIndicator(color: Color(0xFFE53935))),
      // Right side buttons
      Positioned(right: 12, bottom: size.height * 0.25, child: Column(children: [
        _sideBtn(_isLiked ? Icons.favorite : Icons.favorite_border, _formatCount(_likeCount), _isLiked ? const Color(0xFFE53935) : Colors.white, _toggleLike),
        const SizedBox(height: 20),
        _sideBtn(Icons.chat_bubble_outline, '${v.commentsCount ?? 0}', Colors.white, _loadComments),
        const SizedBox(height: 20),
        _sideBtn(Icons.reply, 'Поделиться', Colors.white, () {}),
        const SizedBox(height: 20),
        Container(width: 40, height: 40, decoration: BoxDecoration(color: Color(0xFF333333), borderRadius: BorderRadius.circular(8),
          child: const Icon(Icons.music_note, color: Colors.white, size: 20)),
      ])),
      // Bottom info
      Positioned(left: 12, right: 80, bottom: bottomPad + 16, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(v.user?.channelName ?? v.user?.username ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(width: 10), const Icon(Icons.chevron_right, color: Colors.white54, size: 18),
        ]),
        const SizedBox(height: 6),
        Text(v.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Row(children: [Icon(Icons.play_circle_outline, color: Colors.grey[400], size: 14), const SizedBox(width: 4),
          Text('${v.views} просмотров', style: TextStyle(color: Colors.grey[400], fontSize: 12))]),
      ])),
      // Top bar
      Positioned(top: 0, left: 0, right: 0, child: Container(padding: EdgeInsets.only(top: topPad, left: 8, right: 8, bottom: 8),
        child: Row(children: [
          IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
            onPressed: () { _vp?.pause(); widget.onBack?.call(); }),
          const Expanded(child: Center(child: Text('Shorts', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)))),
          const SizedBox(width: 48),
        ]),
      )),
      // Comments sheet
      if (_showComments) _buildCommentsSheet(auth),
    ]);
  }

  Widget _sideBtn(IconData icon, String count, Color color, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: Column(children: [
      Icon(icon, color: color, size: 30),
      if (count.isNotEmpty) ...[const SizedBox(height: 2),
        Text(count, style: TextStyle(color: Colors.grey[300], fontSize: 11, fontWeight: FontWeight.w500))],
    ]));
  }

  String _formatCount(int c) {
    if (c >= 1000000) return '${(c / 1000000).toStringAsFixed(1)}M';
    if (c >= 1000) return '${(c / 1000).toStringAsFixed(1)}K';
    return c.toString();
  }

  Widget _buildCommentsSheet(AuthProvider auth) {
    return Positioned(left: 0, right: 0, bottom: 0, height: MediaQuery.of(context).size.height * 0.5,
      child: GestureDetector(onVerticalDragEnd: (_) => setState(() => _showComments = false),
        child: Container(decoration: const BoxDecoration(color: Color(0xFF1A1A1A), borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          child: Column(children: [
            Container(margin: const EdgeInsets.only(top: 8), width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2))),
            Padding(padding: const EdgeInsets.all(12),
              child: Text('Комментарии (${v.commentsCount ?? 0})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
            const Divider(color: Colors.grey, height: 1),
            Expanded(child: _loadingComments
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)))
              : _comments.isEmpty
                ? const Center(child: Text('Пока нет комментариев', style: TextStyle(color: Colors.grey)))
                : ListView.builder(padding: const EdgeInsets.all(12), itemCount: _comments.length, itemBuilder: (c, i) {
                    final cm = _comments[i];
                    return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      CircleAvatar(radius: 14, backgroundColor: const Color(0xFF333333),
                        backgroundImage: (cm.user?.avatar ?? '').isNotEmpty ? CachedNetworkImageProvider(cm.user!.avatar!) : null,
                        child: (cm.user?.avatar ?? '').isEmpty
                          ? Text((cm.user?.username ?? '?')[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 11)) : null),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(cm.user?.channelName ?? cm.user?.username ?? '', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                        const SizedBox(height: 2),
                        Text(cm.comment, style: const TextStyle(color: Colors.white, fontSize: 14)),
                      ])),
                    ]));
                  })),
            if (auth.isAuth)
              Container(padding: EdgeInsets.only(left: 12, right: 12, bottom: MediaQuery.of(context).padding.bottom + 8, top: 8),
                child: Row(children: [
                  Expanded(child: TextField(controller: _commentCtrl, style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(hintText: 'Написать комментарий...', hintStyle: TextStyle(color: Colors.grey[600]),
                      filled: true, fillColor: const Color(0xFF2A2A2A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none))),
                  const SizedBox(width: 8),
                  IconButton(icon: const Icon(Icons.send, color: Color(0xFFE53935)), onPressed: _sendComment),
                ])),
          ]),
        ),
      ),
    );
  }
}