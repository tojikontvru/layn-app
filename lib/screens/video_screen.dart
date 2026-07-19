import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  VideoPlayerController? _vp;
  ChewieController? _chewie;
  bool _playerReady = false;
  List<Comment> _comments = [];
  List<Video> _related = [];
  bool _loadingComments = false;
  final _commentCtrl = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _initPlayer();
    _loadComments();
    _loadRelated();
  }

  void _initPlayer() {
    final url = widget.video.videoUrl;
    if (url.isEmpty) return;
    _vp = VideoPlayerController.networkUrl(Uri.parse(url));
    _vp!.initialize().then((_) {
      if (!mounted) return;
      _chewie = ChewieController(videoPlayerController: _vp!, autoPlay: true, allowFullScreen: true, allowMuting: true, showControls: true);
      setState(() => _playerReady = true);
    }).catchError((_) {
      Future.delayed(const Duration(seconds: 3), () { if (mounted) _initPlayer(); });
    });
  }

  Future<void> _loadComments() async {
    setState(() => _loadingComments = true);
    try {
      _comments = await ApiService.instance.comments(widget.video.id);
    } catch (_) {}
    if (mounted) setState(() => _loadingComments = false);
  }

  Future<void> _loadRelated() async {
    try {
      final data = await ApiService.instance.home(page: 1);
      final list = (data['data']?['videos'] as List? ?? [])
          .map((e) => Video.fromJson(e as Map<String, dynamic>))
          .where((v) => !v.isShortsVideo)
          .toList();
      if (mounted) setState(() => _related = list.where((v) => v.id != widget.video.id).take(10).toList());
    } catch (_) {}
  }

  Future<void> _sendComment() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuth) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    try {
      await ApiService.instance.comment(widget.video.id, text);
      _commentCtrl.clear();
      await _loadComments();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  void dispose() {
    _vp?.dispose();
    _chewie?.dispose();
    _commentCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.video;
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Column(
        children: [
          Container(color: Colors.black, width: double.infinity,
            child: AspectRatio(aspectRatio: _playerReady ? _vp!.value.aspectRatio : 16 / 9,
              child: _playerReady && _chewie != null
                ? Chewie(controller: _chewie!)
                : Stack(alignment: Alignment.center, children: [
                    if (v.thumb.isNotEmpty) CachedNetworkImage(imageUrl: v.thumb, fit: BoxFit.cover),
                    const CircularProgressIndicator(color: Color(0xFFE53935)),
                  ]),
            ),
          ),
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.all(12),
              children: [
                Text(v.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('${v.views} просмотров', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                const SizedBox(height: 12),
                Row(children: [
                  CircleAvatar(radius: 18, backgroundColor: const Color(0xFF333333),
                    backgroundImage: (v.user?.avatar ?? '').isNotEmpty ? NetworkImage(v.user!.avatar!) : null,
                    child: (v.user?.avatar == null || v.user!.avatar!.isEmpty)
                      ? Text((v.user?.username ?? '?')[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 14)) : null),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(v.user?.channelName ?? v.user?.username ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ])),
                  ElevatedButton(
                    onPressed: () async {
                      if (!auth.isAuth) { Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())); return; }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
                    child: const Text('Подписаться', style: TextStyle(color: Colors.white))),
                ]),
                const Divider(color: Color(0xFF2A2A2A), height: 24),
                Text('Комментарии (${_comments.length})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                if (_loadingComments)
                  const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)))
                else if (_comments.isEmpty)
                  const Center(child: Padding(padding: EdgeInsets.all(16), child: Text('Пока нет комментариев', style: TextStyle(color: Colors.grey))))
                else
                  ..._comments.map((cm) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      CircleAvatar(radius: 14, backgroundColor: const Color(0xFF333333),
                        backgroundImage: (cm.user?.avatar ?? '').isNotEmpty ? CachedNetworkImageProvider(cm.user!.avatar!) : null,
                        child: (cm.user?.avatar ?? '').isEmpty
                          ? Text((cm.user?.username ?? '?')[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 11)) : null),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(cm.user?.channelName ?? cm.user?.username ?? '', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                        Text(cm.comment, style: const TextStyle(color: Colors.white, fontSize: 14)),
                      ])),
                    ]),
                  )),
                const SizedBox(height: 16),
                if (_related.isNotEmpty) ...[
                  const Text('Похожие видео', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  ..._related.map((r) => VideoCard(video: r, onTap: () {
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => VideoScreen(video: r)));
                    })),
                ],
              ],
            ),
          ),
          if (auth.isAuth)
            Container(
              padding: EdgeInsets.only(left: 12, right: 12, bottom: MediaQuery.of(context).padding.bottom + 8, top: 8),
              decoration: const BoxDecoration(color: Color(0xFF1A1A1A)),
              child: Row(children: [
                Expanded(child: TextField(
                  controller: _commentCtrl, style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(hintText: 'Комментарий...', hintStyle: TextStyle(color: Colors.grey[600]),
                    filled: true, fillColor: const Color(0xFF2A2A2A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none)),
                )),
                const SizedBox(width: 8),
                IconButton(icon: const Icon(Icons.send, color: Color(0xFFE53935)), onPressed: _sendComment),
              ]),
            ),
        ],
      ),
    );
  }
}
