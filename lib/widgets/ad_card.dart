import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';

class AdCard extends StatelessWidget {
  final Ad ad;

  const AdCard({super.key, required this.ad});

  @override
  Widget build(BuildContext context) {
    return _buildFeedAd(context);
  }

  Widget _buildFeedAd(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          if (ad.imageUrl != null && ad.imageUrl!.isNotEmpty)
            CachedNetworkImage(
              imageUrl: ad.imageUrl!,
              height: 150,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                height: 150,
                color: Colors.grey[900],
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              errorWidget: (_, __, ___) => Container(
                height: 150,
                color: Colors.grey[900],
                child: const Center(child: Icon(Icons.broken_image, size: 40)),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge "Реклама"
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Реклама',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // Title
                Text(
                  ad.title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (ad.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    ad.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                // Target button
                GestureDetector(
                  onTap: () => _openUrl(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Подробнее',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openUrl(BuildContext context) async {
    final uri = Uri.tryParse(ad.targetUrl);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
