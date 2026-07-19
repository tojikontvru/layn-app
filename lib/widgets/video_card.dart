import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
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
        margin: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ===== Превью с длительностью =====
          Stack(children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: video.thumb.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: video.thumb,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (_, __) => Container(color: const Color(0xFF1A1A1A)),
                        errorWidget: (_, __, ___) => Container(
                          color: const Color(0xFF1A1A1A),
                          child: const Icon(Icons.play_circle_outline, color: Colors.grey, size: 48),
                        ),
                      )
                    : Container(
                        color: const Color(0xFF1A1A1A),
                        child: const Icon(Icons.play_circle_outline, color: Colors.grey, size: 48),
                      ),
              ),
            ),
            // Длительность — правый нижний угол
            if (video.duration.isNotEmpty)
              Positioned(
                right: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(video.duration,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                ),
              ),
          ]),

          // ===== Информация под превью =====
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Аватарка автора
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF222),
                backgroundImage: (video.user?.avatar ?? '').isNotEmpty
                    ? NetworkImage(video.user!.avatar!)
                    : null,
                child: (video.user?.avatar == null || video.user!.avatar!.isEmpty)
                    ? Text(
                        (video.user?.username ?? 'L')[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              const SizedBox(width: 12),

              // Текст
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Название видео
                  Text(video.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  // Канал + просмотры + дата
                  Text(
                    '${video.channel} • ${video.views} просмотров'
                    '${video.createdAt.isNotEmpty ? ' • ${timeAgo(video.createdAt)}' : ''}',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ]),
              ),

              // Три точки
              IconButton(
                icon: Icon(Icons.more_vert, color: Colors.grey[500], size: 20),
                onPressed: () => _showMenu(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)),
          ),
          ListTile(
            leading: const Icon(Icons.playlist_add, color: Colors.white),
            title: const Text('Сохранить в плейлист', style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.share, color: Colors.white),
            title: const Text('Поделиться', style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.flag_outlined, color: Colors.white),
            title: const Text('Пожаловаться', style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(context),
          ),
        ]),
      ),
    );
  }
}
