import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../models/models.dart';

class VideoCard extends StatelessWidget {
  final Video video;
  final VoidCallback? onTap;

  const VideoCard({super.key, required this.video, this.onTap});

  String _formatViews(int views) {
    if (views >= 1000000) return '${(views / 1000000).toStringAsFixed(1)}M просмотров';
    if (views >= 1000) return '${(views / 1000).toStringAsFixed(1)}K просмотров';
    return '$views просмотров';
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: video.thumb.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: video.thumb,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (_, __) => Container(color: Colors.grey.shade800),
                        errorWidget: (_, __, ___) => Container(
                          color: Colors.grey.shade800,
                          child: const Icon(Icons.error_outline, color: Colors.white54),
                        ),
                      )
                    : Container(
                        color: Colors.grey.shade800,
                        child: const Icon(Icons.play_circle_outline, color: Colors.white54, size: 48),
                      ),
              ),
              // Duration badge
              if (video.duration.isNotEmpty)
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      video.duration,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
            ],
          ),
          // Info row
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                CircleAvatar(
                  radius: 16,
                  backgroundImage: video.avatar != null && video.avatar!.isNotEmpty
                      ? CachedNetworkImageProvider(video.avatar!)
                      : null,
                  child: video.avatar == null || video.avatar!.isEmpty
                      ? Text(
                          video.channel.isNotEmpty ? video.channel[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                // Title + meta
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.3),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${video.channel} · ${_formatViews(video.views)} · ${_formatDate(video.createdAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ),
                // 3-dot menu with share
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, size: 20, color: Theme.of(context).textTheme.bodySmall?.color),
                  onSelected: (v) {
                    if (v == 'share') {
                      Share.share(video.shareUrl);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          Icon(Icons.share, size: 20),
                          SizedBox(width: 12),
                          Text('Поделиться'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
