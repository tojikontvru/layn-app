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
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Thumbnail
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(fit: StackFit.expand, children: [
              if (video.thumb.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: video.thumb,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: const Color(0xFF222)),
                  errorWidget: (_, __, ___) => Container(
                    color: const Color(0xFF222),
                    child: const Icon(Icons.broken_image, color: Colors.grey, size: 32),
                  ),
                )
              else
                Container(color: const Color(0xFF222), child: const Icon(Icons.play_circle_outline, color: Colors.grey, size: 48)),
              // Duration badge
              if (video.duration.isNotEmpty)
                Positioned(
                  right: 8, bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                    child: Text(video.duration, style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ),
            ]),
          ),
          // Info
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFF333),
                backgroundImage: (video.user?.avatar ?? '').isNotEmpty
                    ? NetworkImage(video.user!.avatar!)
                    : null,
                child: (video.user?.avatar == null || video.user!.avatar!.isEmpty)
                    ? Text((video.user?.username ?? '?')[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 12))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(video.title,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(video.channel, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  const SizedBox(height: 2),
                  Text('${video.views} просмотров', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
