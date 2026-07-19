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
  bool _ready = false;
  List<Comment> _comments = [];
  List<Video> _related = [];
  bool _loadingComments = false;
  final _commentCtrl = TextEditingController();

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
      _chewie = ChewieController(videoPlayerController: _vp!, autoPlay: true, allowFullScreen: true);
      setState(() => _ready = true);
    }).catchError((_) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) _initPlayer();
      });
    });
  }

  Future<void> _loadComments() async {
    setState(() => _loadingComments = true);
    try {
      final list = await ApiService.instance.comments(widget.video.id);
      _comments = list.map((e) => Comment.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {}
    if (mounted) setState(() => _loadingComments = false);
  }

  Future<void> _loadRelated() async {
    try {
      final d = await ApiService.instance.home();
      final list = (d['data']?['videos'] as List? ?? [])
          .map((e) => Video.fromJson(e as Map<String, dynamic>))
          .where((v) => !v.isShorts && v.id != widget.video.id)
          .toList();
      if (mounted) setState(() => _related = list.take(10).toList());
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
      await ApiService.instance.sendComment(widget.video.id, text);
      _commentCtrl.clear();
      _loadComments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  void dispose() {
    _vp?.dispose();
    _chewie?.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.video;
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Column(children: [
        // Player
        Container(
          color: Colors.black,
          width: double.infinity,
          child: AspectRatio(
            aspectRatio: _ready && _vp != null ? _vp!.value.aspectRatio : 16 / 9,
            child: _ready && _chewie != null
                ? Chewie(controller: _chewie!)
                : Stack(alignment: Alignment.center, children: [
                    if (v.thumb.isNotEmpty)
                      CachedNetworkImage(imageUrl: v.thumb, fit: BoxFit.cover, width: double.infinity),
                    const CircularProgressIndicator(color: Color(0xFF6C5CE7)),
                  ]),
          ),
        ),

        // Details
        Expanded(
          child: ListView(padding: const EdgeInsets.all(12), children: [
            Text(v.title,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('${v.views} просмотров', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            const SizedBox(height: 16),

            // Channel
            Row(children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF333),
                backgroundImage: (v.user?.avatar ?? '').isNotEmpty
                    ? NetworkImage(abs(v.user!.avatar!))
                    : null,
                child: (v.user?.avatar == null || v.user!.avatar!.isEmpty)
                    ? Text((v.user?.username ?? '?')[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(v.channel,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ]),
            const Divider(color: Color(0xFF222), height: 24),

            // Comments
            Text('Комментарии (${_comments.length})',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            if (_loadingComments)
              const Center(child: CircularProgressIndicator(color: Color(0xFF6C5CE7)))
            else if (_comments.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: Text('Пока нет комментариев', style: TextStyle(color: Colors.grey))),
              )
            else
              ..._comments.map((cm) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: const Color(0xFF333),
                      backgroundImage: (cm.user?.avatar ?? '').isNotEmpty
                          ? CachedNetworkImageProvider(abs(cm.user!.avatar!))
                          : null,
                      child: (cm.user?.avatar ?? '').isEmpty
                          ? Text((cm.user?.username ?? '?')[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontSize: 11))
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(cm.user?.channelName ?? cm.user?.username ?? '',
                            style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                        Text(cm.text, style: const TextStyle(color: Colors.white, fontSize: 14)),
                      ]),
                    ),
                  ]))),

            // Related
            if (_related.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Похожие видео',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              ..._related.map((r) => VideoCard(
                    video: r,
                    onTap: () => Navigator.pushReplacement(
                        context, MaterialPageRoute(builder: (_) => VideoScreen(video: r))),
                  )),
            ],
          ]),
        ),

        // Comment input
        if (auth.isAuth)
          Container(
            padding: EdgeInsets.only(
                left: 12, right: 12, bottom: MediaQuery.of(context).padding.bottom + 8, top: 8),
            decoration: const BoxDecoration(color: Color(0xFF1A1A1A)),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _commentCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Комментарий...',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    filled: true,
                    fillColor: const Color(0xFF2A2A2A),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFF6C5CE7)),
                  onPressed: _sendComment),
            ]),
          ),
      ]),
    );
  }
}
