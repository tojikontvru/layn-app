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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (video.thumb.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: video.thumb,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: const Color(0xFF1A1A1A),
                        child: const Center(child: CircularProgressIndicator(color: Color(0xFFE53935), strokeWidth: 2)),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: const Color(0xFF1A1A1A),
                        child: const Icon(Icons.play_circle_outline, color: Colors.grey, size: 40),
                      ),
                    )
                  else
                    const Center(child: Icon(Icons.play_circle_outline, color: Colors.grey, size: 40)),
                  if (video.duration != null && video.duration!.isNotEmpty)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.75), borderRadius: BorderRadius.circular(4)),
                        child: Text(video.duration!, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Info
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Channel avatar
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFF333333),
                  backgroundImage: (video.user?.avatar ?? '').isNotEmpty ? NetworkImage(video.user!.avatar!) : null,
                  child: (video.user?.avatar == null || video.user!.avatar!.isEmpty)
                      ? Text((video.user?.username ?? '?')[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12))
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text('${video.user?.channelName ?? video.user?.username ?? ""} • ${video.views} просмотров',
                          style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
