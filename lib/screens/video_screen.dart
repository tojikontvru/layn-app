import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/video_card.dart';
import 'login_screen.dart';

class VideoScreen extends StatefulWidget {
  final Video video;
  const VideoScreen({super.key, required this.video});
  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  VideoPlayerController? _videoCtrl;
  ChewieController? _chewieCtrl;
  bool _ready = false;
  int _tab = 0; // 0=Похожие, 1=Комментарии
  final _commentCtrl = TextEditingController();
  List<Comment> _comments = [];
  List<Video> _related = [];
  bool _subscribed = false;
  bool _liked = false;
  bool _disliked = false;
  int _likeCount = 0;

  String get _shareUrl => 'https://layn.su/play/${widget.video.id}/${widget.video.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9а-яё]+'), '-')}';

  @override
  void initState() {
    super.initState();
    _likeCount = widget.video.views;
    _initPlayer();
    _loadComments();
    _loadRelated();
  }

  Future<void> _initPlayer() async {
    try {
      _videoCtrl = VideoPlayerController.networkUrl(
        Uri.parse(widget.video.videoUrl),
        httpHeaders: const {'Referer': 'https://layn.su/', 'Origin': 'https://layn.su'},
      );
      await _videoCtrl!.initialize();
      if (!mounted) return;
      _chewieCtrl = ChewieController(
        videoPlayerController: _videoCtrl!,
        autoPlay: true,
        showControls: true,
        aspectRatio: _videoCtrl!.value.aspectRatio,
      );
      setState(() => _ready = true);
    } catch (e) {
      debugPrint('Video player error: $e');
    }
  }

  Future<void> _loadComments() async {
    try {
      _comments = await ApiService.instance.comments(widget.video.id);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _loadRelated() async {
    try {
      final d = await ApiService.instance.home(page: 1);
      final list = (d['data']?['videos'] as List? ?? [])
          .map((e) => Video.fromJson(e as Map<String, dynamic>))
          .where((v) => v.id != widget.video.id)
          .take(10)
          .toList();
      if (mounted) setState(() => _related = list);
    } catch (_) {}
  }

  void _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    final auth = context.read<AuthProvider>();
    if (!auth.loggedIn) { _showLoginPrompt(); return; }
    setState(() {
      _comments.insert(0, Comment(
        id: 0, text: text,
        user: VideoUser(username: auth.user?.username, avatar: auth.user?.avatar),
      ));
      _commentCtrl.clear();
    });
    try { await ApiService.instance.sendComment(widget.video.id, text); } catch (_) {}
  }

  void _onLike() async {
    final auth = context.read<AuthProvider>();
    if (!auth.loggedIn) { _showLoginPrompt(); return; }
    setState(() { _liked = !_liked; if (_liked) _disliked = false; _likeCount += _liked ? 1 : -1; });
    try { await ApiService.instance.reaction(widget.video.id, 'like'); } catch (_) {}
  }

  void _onDislike() async {
    final auth = context.read<AuthProvider>();
    if (!auth.loggedIn) { _showLoginPrompt(); return; }
    setState(() { _disliked = !_disliked; if (_disliked) _liked = false; });
    try { await ApiService.instance.reaction(widget.video.id, 'dislike'); } catch (_) {}
  }

  void _onSubscribe() async {
    final auth = context.read<AuthProvider>();
    if (!auth.loggedIn) { _showLoginPrompt(); return; }
    setState(() => _subscribed = !_subscribed);
    try { await ApiService.instance.subscribe(widget.video.user?.id ?? 0); } catch (_) {}
  }

  void _showDescription() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6, maxChildSize: 0.9, minChildSize: 0.3,
        expand: false,
        builder: (_, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(20),
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text(widget.video.title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('${_formatViews(widget.video.views)} • ${_timeAgo(widget.video.createdAt)}',
                style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            const Divider(color: Colors.white10, height: 24),
            Text(widget.video.description.isNotEmpty ? widget.video.description : 'Нет описания',
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLoginPrompt() {
    showModalBottomSheet(context: context, backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.person_outline, color: Colors.white, size: 48),
          const SizedBox(height: 16),
          const Text('Войдите в аккаунт', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Чтобы комментировать и ставить лайки', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6C5CE7), padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())); },
            child: const Text('Войти', style: TextStyle(fontSize: 16)),
          )),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  @override
  void dispose() {
    _chewieCtrl?.dispose();
    _videoCtrl?.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(children: [
          // Video player (no AppBar - YouTube style)
          if (_ready && _chewieCtrl != null)
            AspectRatio(aspectRatio: _videoCtrl!.value.aspectRatio, child: Chewie(controller: _chewieCtrl!))
          else
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(children: [
                if (widget.video.thumbnailUrl.isNotEmpty)
                  Image.network(widget.video.thumbnailUrl, fit: BoxFit.cover, width: double.infinity),
                const Center(child: CircularProgressIndicator(color: Colors.white)),
              ]),
            ),

          Expanded(
            child: ListView(padding: const EdgeInsets.symmetric(horizontal: 12), children: [
              const SizedBox(height: 8),
              // Title
              Text(widget.video.title,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),

              // Action buttons row (YouTube style)
              SizedBox(
                height: 40,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  _ytAction(Icons.thumb_up_outlined, _liked ? Icons.thumb_up : null,
                      _formatCount(_likeCount), _onLike),
                  const SizedBox(width: 4),
                  _ytAction(Icons.thumb_down_outlined, _disliked ? Icons.thumb_down : null,
                      '', _onDislike),
                  const SizedBox(width: 4),
                  _ytAction(Icons.reply_outlined, null, 'Поделиться',
                      () => Share.share('${widget.video.title}\n$_shareUrl')),
                  const SizedBox(width: 4),
                  _ytAction(Icons.download_outlined, null, 'Скачать', () {}),
                  const SizedBox(width: 4),
                  _ytAction(Icons.bookmark_border_outlined, null, 'Сохранить', () {}),
                ]),
              ),
              const Divider(color: Colors.white10, height: 16),

              // Channel row
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  CircleAvatar(
                    radius: 18, backgroundColor: const Color(0xFF333),
                    backgroundImage: (widget.video.avatar ?? '').isNotEmpty ? NetworkImage(widget.video.avatar!) : null,
                    child: (widget.video.avatar == null || widget.video.avatar!.isEmpty)
                        ? Text(widget.video.username[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 13))
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.video.channelName ?? widget.video.username,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                    Text('подписчиков', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                  ])),
                  FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: _subscribed ? const Color(0xFF333) : Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16)),
                    onPressed: _onSubscribe,
                    child: Text(_subscribed ? 'Подписан' : 'Подписаться',
                        style: TextStyle(color: _subscribed ? Colors.grey : Colors.black, fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),

              // Description button (info icon)
              GestureDetector(
                onTap: _showDescription,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    const Icon(Icons.info_outline, color: Colors.white70, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      widget.video.description.isNotEmpty
                          ? widget.video.description.substring(0, widget.video.description.length.clamp(0, 80))
                          : 'Нет описания',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    )),
                    const Icon(Icons.keyboard_arrow_down, color: Colors.white30),
                  ]),
                ),
              ),

              // Tabs
              Container(
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white10))),
                child: Row(children: [
                  _tabBtn('Похожие видео', 0),
                  _tabBtn('Комментарии (${_comments.length})', 1),
                ]),
              ),
              const SizedBox(height: 8),

              // Tab content
              if (_tab == 0)
                ..._related.map((v) => VideoCard(
                  video: v,
                  onTap: () => Navigator.pushReplacement(context,
                      MaterialPageRoute(builder: (_) => VideoScreen(video: v))),
                ))
              else ...[
                // Comment input
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _commentCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Добавить комментарий...',
                          hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                          filled: true, fillColor: const Color(0xFF1A1A1A),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(icon: const Icon(Icons.send, color: Color(0xFF6C5CE7), size: 20), onPressed: _sendComment),
                  ]),
                ),
                // Comments list
                ..._comments.map((cm) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    CircleAvatar(
                      radius: 12, backgroundColor: const Color(0xFF333),
                      backgroundImage: (cm.user?.avatar ?? '').isNotEmpty ? CachedNetworkImageProvider(cm.user!.avatar!) : null,
                      child: (cm.user?.avatar ?? '').isEmpty
                          ? Text((cm.user?.username ?? '?')[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontSize: 10))
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('@${cm.user?.username ?? 'user'}',
                          style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.w500)),
                      Text(cm.text, style: const TextStyle(color: Colors.white, fontSize: 13)),
                    ])),
                  ]),
                )),
                if (_comments.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text('Нет комментариев', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ),
              ],
              const SizedBox(height: 16),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _ytAction(IconData icon, IconData? activeIcon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(activeIcon ?? icon, color: activeIcon != null ? Colors.white : Colors.white70, size: 18),
          if (label.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ]),
      ),
    );
  }

  Widget _tabBtn(String label, int idx) {
    final active = _tab == idx;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _tab = idx),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: active ? Colors.white : Colors.transparent, width: 2)),
        ),
        child: Text(label, textAlign: TextAlign.center,
            style: TextStyle(color: active ? Colors.white : Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w600)),
      ),
    ));
  }

  String _formatViews(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M просмотров';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K просмотров';
    return '$v просмотров';
  }

  String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  String _timeAgo(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(date);
      if (diff.inDays > 365) return '${(diff.inDays / 365).floor()} г. назад';
      if (diff.inDays > 30) return '${(diff.inDays / 30).floor()} мес. назад';
      if (diff.inDays > 0) return '${diff.inDays} дн. назад';
      if (diff.inHours > 0) return '${diff.inHours} ч. назад';
      if (diff.inMinutes > 0) return '${diff.inMinutes} мин. назад';
      return 'только что';
    } catch (_) { return ''; }
  }
}
