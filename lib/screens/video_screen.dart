import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import '../widgets/video_card.dart';

class VideoScreen extends StatefulWidget {
  final Video video;
  final List<Video>? related;

  const VideoScreen({super.key, required this.video, this.related});

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  late VideoPlayerController _vpc;
  ChewieController? _cc;
  bool _loading = true;
  bool _liked = false;
  bool _disliked = false;
  int _likeCount = 0;
  bool _subscribed = false;
  List<Comment> _comments = [];
  bool _showDescription = false;
  int _selectedTab = 0;
  bool _disposed = false;

  late String _shareUrl;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.video.views;
    _shareUrl = widget.video.shareUrl;
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      final url = abs(widget.video.videoUrl);
      _vpc = VideoPlayerController.networkUrl(Uri.parse(url));
      await _vpc.initialize();
      if (_disposed) return;
      _cc = ChewieController(
        videoPlayerController: _vpc,
        autoPlay: true,
        looping: false,
        aspectRatio: _vpc.value.aspectRatio,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: Theme.of(context).colorScheme.primary,
          handleColor: Theme.of(context).colorScheme.primary,
          bufferedColor: Colors.grey.shade700,
        ),
        placeholder: Container(color: Colors.black),
        errorBuilder: (_, msg) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 8),
              Text('Ошибка воспроизведения', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
      WakelockPlus.enable();
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _cc?.dispose();
    _vpc.dispose();
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  Future<void> _onLike() async {
    final api = Provider.of<ApiService>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuth) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Войдите, чтобы ставить лайки')),
      );
      return;
    }
    try {
      await api.reaction(widget.video.id, 'like');
      setState(() {
        _liked = !_liked;
        if (_liked) {
          _likeCount++;
          _disliked = false;
        } else {
          _likeCount--;
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  Future<void> _onDislike() async {
    final api = Provider.of<ApiService>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuth) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Войдите, чтобы ставить дизлайки')),
      );
      return;
    }
    try {
      await api.reaction(widget.video.id, 'dislike');
      setState(() {
        _disliked = !_disliked;
        if (_disliked) {
          _liked = false;
          _likeCount = _likeCount > 0 ? _likeCount - 1 : 0;
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  Future<void> _onSubscribe() async {
    final api = Provider.of<ApiService>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuth) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Войдите, чтобы подписаться')),
      );
      return;
    }
    try {
      await api.subscribe(widget.video.userId ?? widget.video.id);
      setState(() => _subscribed = !_subscribed);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  Future<void> _loadComments() async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      _comments = await api.comments(widget.video.id);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Video player
            if (_loading)
              const AspectRatio(
                aspectRatio: 16 / 9,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_cc != null)
              AspectRatio(
                aspectRatio: _cc!.videoPlayerController.value.aspectRatio > 0
                    ? _cc!.videoPlayerController.value.aspectRatio
                    : 16 / 9,
                child: Chewie(controller: _cc!),
              )
            else
              Container(
                height: 200,
                color: Colors.black,
                child: const Center(
                  child: Text('Не удалось загрузить видео', style: TextStyle(color: Colors.white)),
                ),
              ),

            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // Title + Ещё button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.video.title,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () => setState(() => _showDescription = !_showDescription),
                          child: Row(
                            children: [
                              Text(
                                '${_formatCount(_likeCount)} лайков · ${widget.video.channel}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(context).textTheme.bodySmall?.color,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _showDescription ? 'Свернуть' : 'Ещё',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Action buttons row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _ytAction(Icons.thumb_up_outlined, _liked ? Icons.thumb_up : null,
                            _formatCount(_likeCount), _onLike),
                        _ytAction(Icons.thumb_down_outlined, _disliked ? Icons.thumb_down : null,
                            '', _onDislike),
                        _ytAction(Icons.share, null, 'Поделиться',
                            () => Share.share(_shareUrl)),
                        _ytAction(Icons.bookmark_border_outlined, null, 'Сохранить', () {}),
                      ],
                    ),
                  ),

                  // Description expanded
                  if (_showDescription) ...[
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_formatCount(_likeCount)} лайков · ${widget.video.channel}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).textTheme.bodySmall?.color,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (widget.video.description.isNotEmpty)
                            Text(
                              widget.video.description,
                              style: const TextStyle(fontSize: 13),
                            ),
                        ],
                      ),
                    ),
                  ],

                  // Channel row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundImage: widget.video.avatar != null && widget.video.avatar!.isNotEmpty
                              ? CachedNetworkImageProvider(normalizeUrl(widget.video.avatar!))
                              : null,
                          child: widget.video.avatar == null || widget.video.avatar!.isEmpty
                              ? Text(
                                  widget.video.channel.isNotEmpty
                                      ? widget.video.channel[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.video.channel,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              Text(
                                widget.video.username,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).textTheme.bodySmall?.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: _onSubscribe,
                          style: TextButton.styleFrom(
                            backgroundColor: _subscribed
                                ? Theme.of(context).colorScheme.surfaceContainerHighest
                                : Theme.of(context).colorScheme.primary,
                            foregroundColor: _subscribed
                                ? Theme.of(context).textTheme.bodyLarge?.color
                                : Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          child: Text(
                            _subscribed ? 'Подписан' : 'Подписаться',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tabs: Похожие / Комментарии
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _selectedTab = 0);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: _selectedTab == 0
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'Похожие',
                                  style: TextStyle(
                                    fontWeight: _selectedTab == 0 ? FontWeight.w600 : FontWeight.normal,
                                    color: _selectedTab == 0
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).textTheme.bodySmall?.color,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _selectedTab = 1);
                              _loadComments();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: _selectedTab == 1
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'Комментарии',
                                  style: TextStyle(
                                    fontWeight: _selectedTab == 1 ? FontWeight.w600 : FontWeight.normal,
                                    color: _selectedTab == 1
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).textTheme.bodySmall?.color,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tab content
                  if (_selectedTab == 0) ...[
                    if (widget.related != null && widget.related!.isNotEmpty)
                      ...widget.related!.map((v) => VideoCard(
                            video: v,
                            onTap: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => VideoScreen(video: v, related: widget.related),
                                ),
                              );
                            },
                          ))
                    else
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: Text('Нет похожих видео')),
                      ),
                  ] else ...[
                    if (_comments.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else
                      ..._comments.map((c) => _buildComment(c)),
                    // Comment input
                    _buildCommentInput(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ytAction(IconData icon, IconData? activeIcon, String label, VoidCallback onTap) {
    final isActive = activeIcon != null;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? activeIcon : icon,
            size: 22,
            color: isActive ? Theme.of(context).colorScheme.primary : null,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComment(Comment c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            child: Text(
              (c.user?.username ?? '').isNotEmpty ? (c.user?.username ?? '?')[0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.user?.username ?? '',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(c.text, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    final ctrl = TextEditingController();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          const CircleAvatar(radius: 14, child: Icon(Icons.person, size: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: ctrl,
              decoration: InputDecoration(
                hintText: 'Добавить комментарий...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.send, size: 20, color: Theme.of(context).colorScheme.primary),
            onPressed: () async {
              final text = ctrl.text.trim();
              if (text.isEmpty) return;
              final api = Provider.of<ApiService>(context, listen: false);
              final auth = Provider.of<AuthProvider>(context, listen: false);
              if (!auth.isAuth) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Войдите, чтобы оставить комментарий')),
                );
                return;
              }
              try {
                await api.sendComment(widget.video.id, text);
                ctrl.clear();
                _loadComments();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Ошибка: $e')),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
