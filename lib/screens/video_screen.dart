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
import 'register_screen.dart';

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
  final _commentCtrl = TextEditingController();
  List<Comment> _comments = [];
  List<Video> _related = [];
  bool _subscribed = false;
  int _subCount = 0;
  bool _liked = false;
  bool _disliked = false;
  int _likeCount = 0;
  int _dislikeCount = 0;

  @override
  void initState() {
    super.initState();
    _initPlayer();
    _loadComments();
    _loadRelated();
    _likeCount = widget.video.views;
    _subscribed = false;
  }

  Future<void> _initPlayer() async {
    try {
      _videoCtrl = VideoPlayerController.networkUrl(Uri.parse(widget.video.videoUrl),
          httpHeaders: const {'Referer': 'https://layn.su/', 'Origin': 'https://layn.su'});
      await _videoCtrl!.initialize();
      if (!mounted) return;
      _chewieCtrl = ChewieController(
        videoPlayerController: _videoCtrl!,
        autoPlay: true, showControls: true,
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

    try {
      await ApiService.instance.sendComment(widget.video.id, text);
      _loadComments();
    } catch (_) {}
  }

  void _onLike() async {
    final auth = context.read<AuthProvider>();
    if (!auth.loggedIn) { _showLoginPrompt(); return; }
    setState(() {
      _liked = !_liked;
      if (_liked) _disliked = false;
      _likeCount += _liked ? 1 : -1;
    });
    try { await ApiService.instance.reaction(widget.video.id, 'like'); } catch (_) {}
  }

  void _onDislike() async {
    final auth = context.read<AuthProvider>();
    if (!auth.loggedIn) { _showLoginPrompt(); return; }
    setState(() {
      _disliked = !_disliked;
      if (_disliked) _liked = false;
    });
    try { await ApiService.instance.reaction(widget.video.id, 'dislike'); } catch (_) {}
  }

  void _onSubscribe() async {
    final auth = context.read<AuthProvider>();
    if (!auth.loggedIn) { _showLoginPrompt(); return; }
    setState(() => _subscribed = !_subscribed);
    try { await ApiService.instance.subscribe(widget.video.user?.id ?? 0); } catch (_) {}
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
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: OutlinedButton(
            style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF6C5CE7)), padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())); },
            child: const Text('Регистрация', style: TextStyle(color: Color(0xFF6C5CE7), fontSize: 16)),
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
          // Video player
          if (_ready && _chewieCtrl != null)
            AspectRatio(
              aspectRatio: _videoCtrl!.value.aspectRatio,
              child: Chewie(controller: _chewieCtrl!),
            )
          else
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                color: const Color(0xFF111),
                child: const Center(child: CircularProgressIndicator(color: Color(0xFF6C5CE7))),
              ),
            ),

          // Info + actions
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                // Title
                Text(widget.video.title,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(
                  '${_formatViews(widget.video.views)} • ${_timeAgo(widget.video.createdAt)}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
                const SizedBox(height: 12),

                // Action buttons
                Row(children: [
                  _actionBtn(
                    icon: _liked ? Icons.thumb_up : Icons.thumb_up_outlined,
                    label: _formatCount(_likeCount),
                    active: _liked,
                    onTap: _onLike,
                  ),
                  const SizedBox(width: 8),
                  _actionBtn(
                    icon: _disliked ? Icons.thumb_down : Icons.thumb_down_outlined,
                    label: '',
                    active: _disliked,
                    onTap: _onDislike,
                  ),
                  const SizedBox(width: 8),
                  _actionBtn(
                    icon: Icons.reply,
                    label: 'Поделиться',
                    onTap: () => SharePlus.instance.share(
                      ShareParams(
                        text: '${widget.video.title}\nhttps://layn.su/video/${widget.video.id}',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _actionBtn(icon: Icons.download, label: 'Скачать', onTap: () {}),
                ]),
                const SizedBox(height: 12),

                // Channel + subscribe
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFF333),
                      backgroundImage: (widget.video.avatar ?? '').isNotEmpty
                          ? NetworkImage(widget.video.avatar!) : null,
                      child: (widget.video.avatar == null || widget.video.avatar!.isEmpty)
                          ? Text((widget.video.username[0]).toUpperCase(),
                              style: const TextStyle(color: Colors.white))
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(widget.video.channelName ?? widget.video.username,
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                        if (_subCount > 0)
                          Text('$_subCount подписчиков',
                              style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                      ]),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _subscribed ? const Color(0xFF333) : const Color(0xFF6C5CE7),
                      ),
                      onPressed: _onSubscribe,
                      child: Text(_subscribed ? 'Подписан' : 'Подписаться',
                          style: const TextStyle(fontSize: 13)),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),

                // Description
                if (widget.video.description.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(widget.video.description,
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ),
                const SizedBox(height: 20),

                // Comments header
                Row(children: [
                  const Icon(Icons.comment_outlined, color: Colors.white70, size: 20),
                  const SizedBox(width: 8),
                  Text('Комментарии (${_comments.length})',
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 12),

                // Comment input
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _commentCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Добавить комментарий...',
                        hintStyle: TextStyle(color: Colors.grey[600]),
                        filled: true,
                        fillColor: const Color(0xFF1A1A1A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send, color: Color(0xFF6C5CE7)),
                    onPressed: _sendComment,
                  ),
                ]),
                const SizedBox(height: 16),

                // Comments list
                ..._comments.map((cm) => _buildComment(cm)),
                const SizedBox(height: 20),

                // Related videos
                if (_related.isNotEmpty) ...[
                  const Text('Похожие видео',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ..._related.map((v) => VideoCard(
                    video: v,
                    onTap: () => Navigator.pushReplacement(context,
                        MaterialPageRoute(builder: (_) => VideoScreen(video: v))),
                  )),
                ],
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildComment(Comment cm) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(
          radius: 14, backgroundColor: const Color(0xFF333),
          backgroundImage: (cm.user?.avatar ?? '').isNotEmpty
              ? CachedNetworkImageProvider(cm.user!.avatar!) : null,
          child: (cm.user?.avatar ?? '').isEmpty
              ? Text((cm.user?.username ?? '?')[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 11))
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('@${cm.user?.username ?? 'user'}',
                style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(cm.text, style: const TextStyle(color: Colors.white, fontSize: 13)),
          ]),
        ),
      ]),
    );
  }

  Widget _actionBtn({required IconData icon, String? label, bool active = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Icon(icon, color: active ? const Color(0xFF6C5CE7) : Colors.white70, size: 22),
        if (label != null && label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
          ),
      ]),
    );
  }

  String _formatViews(int views) {
    if (views >= 1000000) return '${(views / 1000000).toStringAsFixed(1)}M просмотров';
    if (views >= 1000) return '${(views / 1000).toStringAsFixed(1)}K просмотров';
    return '$views просмотров';
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
    } catch (_) {
      return '';
    }
  }
}
