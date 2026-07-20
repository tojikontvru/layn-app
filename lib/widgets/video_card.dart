import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/models.dart';

class VideoCard extends StatelessWidget {
  final Video video;
  final VoidCallback onTap;

  const VideoCard({super.key, required this.video, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12)
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Thumbnail with duration
          Stack(children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12)
                child: CachedNetworkImage(
                  imageUrl: video.thumbnailUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder: (_, __) => Container(color: const Color(0xFF222))
                  errorWidget: (_, __, ___) => Container(
                    color: const Color(0xFF222)
                    child: const Icon(Icons.play_circle_outline, color: Colors.white24, size: 48)
                  )
                )
              )
            )
            // Duration badge
            if (video.duration.isNotEmpty)
              Positioned(
                right: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(4)
                  )
                  child: Text(video.duration,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500))
                )
              )
          ])
          const SizedBox(height: 10)
          // Info row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4)
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Avatar
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF222)
                backgroundImage: (video.avatar ?? '').isNotEmpty
                    ? NetworkImage(video.avatar!)
                    : null,
                child: (video.avatar == null || video.avatar!.isEmpty)
                    ? Text((video.username.isNotEmpty ? video.username[0] : 'L').toUpperCase()
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))
                    : null,
              )
              const SizedBox(width: 12)
              // Title + meta
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(video.title,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)
                      maxLines: 2, overflow: TextOverflow.ellipsis)
                  const SizedBox(height: 4)
                  Text(
                    '${video.channelName ?? video.username} • ${_formatViews(video.views)} • ${_timeAgo(video.createdAt)}',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12)
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  )
                ])
              )
              // Menu
              IconButton(
                icon: Icon(Icons.more_vert, color: Colors.grey[500], size: 20)
                onPressed: () => _showMenu(context)
              )
            ])
          )
        ])
      )
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E)
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16)))
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.share, color: Colors.white)
          title: const Text('Поделиться', style: TextStyle(color: Colors.white))
          onTap: () {
            Navigator.pop(context);
              Share.share('${video.title}\nhttps://layn.su/video/${video.id}'),
          },
        )
        ListTile(
          leading: const Icon(Icons.download, color: Colors.white)
          title: const Text('Скачать', style: TextStyle(color: Colors.white))
          onTap: () => Navigator.pop(context)
        )
        ListTile(
          leading: const Icon(Icons.flag_outlined, color: Colors.white)
          title: const Text('Пожаловаться', style: TextStyle(color: Colors.white))
          onTap: () => Navigator.pop(context)
        )
      ]))
    );
  }

  String _formatViews(int views) {
    if (views >= 1000000) return '${(views / 1000000).toStringAsFixed(1)}M просмотров';
    if (views >= 1000) return '${(views / 1000).toStringAsFixed(1)}K просмотров';
    return '$views просмотров';
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
