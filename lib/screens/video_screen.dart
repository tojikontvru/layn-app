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
  ChewieController? _cc;
  VideoPlayerController? _vpc;
  bool _loading = true;
  bool _liked = false;
  bool _disliked = false;
  int _likeCount = 0;
  bool _subscribed = false;
  List<Comment> _comments = [];
  bool _showDescription = false;
  int _selectedTab = 0;
  bool _disposed = false;
  String? _videoError;

  late String _shareUrl;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.video.views;
    _shareUrl = widget.video.shareUrl;
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      final url = abs(widget.video.videoUrl);
      if (url.isEmpty) {
        setState(() {
          _loading = false;
          _videoError = 'Ссылка на видео отсутствует';
        });
        return;
      }
      _vpc = VideoPlayerController.networkUrl(Uri.parse(url));
      await _vpc!.initialize();
      if (_disposed) return;
      _cc = ChewieController(
        videoPlayerController: _vpc!,
        autoPlay: true,
        looping: false,
        aspectRatio: _vpc!.value.aspectRatio > 0
            ? _vpc!.value.aspectRatio
            : 16 / 9,
        allowFullScreen: true,
        allowMuting: true,
        showControlsOnInitialize: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: Theme.of(context).colorScheme.primary,
          handleColor: Theme.of(context).colorScheme.primary,
          bufferedColor: Colors.grey.shade700,
        ),
        placeholder: Container(color: Colors.black),
        errorBuilder: (_, msg) => Container(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 8),
                Text(msg ?? 'Ошибка воспроизведения',
                    style: const TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ),
      );
      WakelockPlus.enable();
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (!_disposed && mounted) {
        setState(() {
          _loading = false;
          _videoError = 'Не удалось загрузить видео';
        });
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _cc?.dispose();
    _vpc?.dispose();
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  String _formatViews(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M просмотров';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K просмотров';
    return '$n просмотров';
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inDays > 365) return '${(diff.inDays / 365).floor()} г. назад';
      if (diff.inDays > 30) return '${(diff.inDays / 30).floor()} мес. назад';
      if (diff.inDays > 0) return '${diff.inDays} дн. назад';
      if (diff.inHours > 0) return '${diff.inHours} ч. назад';
      if (diff.inMinutes > 0) return '${diff.inMinutes} мин. назад';
      return 'Только что';
    } catch (_) {
      return dateStr;
    }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
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
    } catch (_) {}
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
    if (widget.video.userId != null && widget.video.userId == auth.userId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нельзя подписаться на свой канал')),
      );
      return;
    }
    try {
      await api.subscribe(widget.video.userId ?? 0);
      setState(() => _subscribed = !_subscribed);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
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
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isMyVideo = widget.video.userId != null &&
        widget.video.userId == auth.userId;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // Video player — NO header above it, just SafeArea padding
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                if (_loading)
                  const AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Center(child: CircularProgressIndicator(color: Colors.white)),
                  )
                else if (_videoError != null)
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      color: Colors.black,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 48),
                            const SizedBox(height: 8),
                            Text(_videoError!,
                                style: const TextStyle(color: Colors.white),
                                textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _loading = true;
                                  _videoError = null;
                                });
                                _initVideo();
                              },
                              child: const Text('Повторить',
                                  style: TextStyle(color: Color(0xFF3EA6FF))),
                            ),
                          ],
                        ),
                      ),
                    ),
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
                      child: Text('Не удалось загрузить видео',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Title
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(
                    widget.video.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Views + date + "Ещё" for description
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: GestureDetector(
                    onTap: () => setState(() => _showDescription = !_showDescription),
                    child: Row(
                      children: [
                        Text(
                          '${_formatViews(widget.video.views)} · ${_formatDate(widget.video.createdAt)}',
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
                ),

                // Action buttons row — like count ONLY under like icon
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _ytAction(
                        Icons.thumb_up_outlined,
                        _liked ? Icons.thumb_up : null,
                        _formatCount(_likeCount),
                        _onLike,
                      ),
                      _ytAction(
                        Icons.thumb_down_outlined,
                        _disliked ? Icons.thumb_down : null,
                        '',
                        _onDislike,
                      ),
                      _ytAction(Icons.share, null, 'Поделиться',
                          () => Share.share(_shareUrl)),
                    ],
                  ),
                ),

                // Description expanded
                if (_showDescription) ...[
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.video.description.isNotEmpty)
                          Text(
                            widget.video.description,
                            style: const TextStyle(fontSize: 13),
                          )
                        else
                          Text(
                            'Описание отсутствует',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).textTheme.bodySmall?.color,
                            ),
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
                        backgroundImage: widget.video.avatar != null &&
                                widget.video.avatar!.isNotEmpty
                            ? CachedNetworkImageProvider(abs(widget.video.avatar!))
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
                          ],
                        ),
                      ),
                      if (!isMyVideo)
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

                const SizedBox(height: 8),

                // Tabs: Похожие / Комментарии
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedTab = 0),
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

                // Tab content
                if (_selectedTab == 0) ...[
                  if (widget.related != null && widget.related!.isNotEmpty)
                    ...widget.related!
                        .where((v) => v.id != widget.video.id)
                        .map((v) => VideoCard(
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
                  _buildCommentInput(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ytAction(
      IconData icon, IconData? activeIcon, String label, VoidCallback onTap) {
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
    final uname = c.user?.username ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundImage: c.user?.avatar != null && c.user!.avatar!.isNotEmpty
                ? CachedNetworkImageProvider(abs(c.user!.avatar!))
                : null,
            child: uname.isEmpty || c.user?.avatar == null || c.user!.avatar!.isEmpty
                ? Text(
                    uname.isNotEmpty ? uname[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 12),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  uname,
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
          top: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.2)),
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
            icon: Icon(Icons.send,
                size: 20, color: Theme.of(context).colorScheme.primary),
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
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ошибка: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
