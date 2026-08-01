import 'package:intl/intl.dart';

String abs(String url) {
  if (url.isEmpty) return url;
  if (url.startsWith('http')) return url;
  if (url.startsWith('//')) return 'https:$url';
  return 'https://layn.su$url';
}

/// Нормализует URL для сравнения: убирает query-параметры, trailing slash, lowercase
String normalizeUrl(String url) {
  if (url.isEmpty) return url;
  try {
    final u = Uri.parse(url);
    // Убираем query и fragment, lowercase path
    return '${u.scheme}://${u.host}${u.path}'.toLowerCase().replaceAll(RegExp(r'/+$'), '');
  } catch (_) {
    return url.toLowerCase().replaceAll(RegExp(r'\?.*'), '').replaceAll(RegExp(r'/+$'), '');
  }
}

String timeAgo(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return '';
  try {
    final date = DateTime.parse(dateStr);
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inSeconds < 60) return 'только что';
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин. назад';
    if (diff.inHours < 24) return '${diff.inHours} ч. назад';
    if (diff.inDays < 7) return '${diff.inDays} дн. назад';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} нед. назад';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} мес. назад';
    return DateFormat('dd.MM.yyyy').format(date);
  } catch (_) {
    return dateStr;
  }
}

class Video {
  final int id;
  final int? userId;
  final String title;
  final String description;
  final String thumbnailUrl;
  final String videoUrl;
  final String? hlsUrl;
  final String username;
  final int views;
  final String duration;
  final String createdAt;
  final String? categorySlug;
  final String? slug;
  final String? channelName;
  final String? avatar;
  final int? commentsCount;
  final int? likesCount;

  Video({
    required this.id,
    this.userId,
    required this.title,
    this.description = '',
    required this.thumbnailUrl,
    required this.videoUrl,
    this.hlsUrl,
    required this.username,
    this.views = 0,
    this.duration = '',
    this.createdAt = '',
    this.channelName,
    this.avatar,
    this.commentsCount,
      this.likesCount,
    this.categorySlug,
    this.slug,
  });

  String get thumb => abs(thumbnailUrl);
  String get channel => channelName ?? username;
  String get shareUrl {
    final s = slug ?? title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'-+'), '-').replaceAll(RegExp(r'^-|-$'), '');
    return 'https://layn.su/play/$id/$s';
  }

  VideoUser? get user => username.isNotEmpty
      ? VideoUser(username: username, channelName: channelName, avatar: avatar)
      : null;

  factory Video.fromJson(Map<String, dynamic> j) => Video(
        id: j['id'] ?? 0,
        userId: j['user']?['id'],
        title: j['title'] ?? '',
        description: j['description'] ?? '',
        thumbnailUrl: j['thumb'] ?? j['thumbnail_url'] ?? '',
        videoUrl: j['video_url'] ?? '',
        hlsUrl: j['hls_playlist'] != null && j['hls_playlist'].toString().isNotEmpty
            ? abs(j['hls_playlist'])
            : null,
        username: j['user']?['username'] ?? j['username'] ?? '',
        views: j['views'] ?? 0,
        duration: j['duration'] ?? '',
        createdAt: j['created_at'] ?? '',
        channelName: j['user']?['channel_name'] ?? j['channel_name'] ?? j['firstname'],
        avatar: abs(j['user']?['avatar'] ?? j['avatar'] ?? ''),
        commentsCount: j['comments_count'],
        likesCount: j['likes_count'] ?? j['likes'],
        categorySlug: j['category']?['slug'] ?? j['category_slug'] ?? j['slug'],
        slug: j['slug'],
      );
}

class VideoUser {
  final int? id;
  final String? username;
  final String? channelName;
  final String? avatar;
  VideoUser({this.id, this.username, this.channelName, this.avatar});
}

class Comment {
  final int id;
  final String text;
  final VideoUser? user;
  Comment({required this.id, required this.text, this.user});

  factory Comment.fromJson(Map<String, dynamic> j) => Comment(
        id: j['id'] ?? 0,
        text: j['comment'] ?? '',
        user: j['user'] != null
            ? VideoUser(
                id: j['user']['id'],
                username: j['user']['username'],
                channelName: j['user']['channel_name'],
                avatar: abs(j['user']['avatar'] ?? ''))
            : null,
      );
}

class Category {
  final int id;
  final String name;
  final String slug;

  Category({required this.id, required this.name, required this.slug});

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: j['id'] ?? 0,
        name: j['name'] ?? '',
        slug: j['slug'] ?? '',
      );
}


/// Уведомление/новость из админки (push-рассылка)
class AppNotification {
  final int id;
  final String subject;
  final String message;
  final String? imageUrl;
  final String? videoUrl;
  final String createdAt;
  final List<AppLink> links;

  AppNotification({
    required this.id,
    required this.subject,
    this.message = '',
    this.imageUrl,
    this.videoUrl,
    this.createdAt = '',
    this.links = const [],
  });

  String get image => imageUrl != null && imageUrl!.isNotEmpty ? abs(imageUrl!) : '';
  String get video => videoUrl != null && videoUrl!.isNotEmpty ? abs(videoUrl!) : '';

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] ?? 0,
        subject: j['subject']?.toString() ?? '',
        message: j['message']?.toString() ?? '',
        imageUrl: j['image']?.toString(),
        videoUrl: j['video']?.toString(),
        createdAt: j['created_at']?.toString() ?? '',
        links: (j['links'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map((e) => AppLink.fromJson(e))
            .toList(),
      );
}

/// Ссылка/кнопка внутри поста (извлекается из HTML сообщения).
class AppLink {
  final String text;
  final String url;

  const AppLink({required this.text, required this.url});

  factory AppLink.fromJson(Map<String, dynamic> j) => AppLink(
        text: j['text']?.toString() ?? '',
        url: j['url']?.toString() ?? '',
      );
}

/// Ad model for in-app advertisements
class Ad {  final int id;
  final String type; // 'feed', 'shorts', 'player'
  final String title;
  final String description;
  final String? imageUrl;
  final String? videoUrl;
  final String targetUrl;
  final int interval;
  final int startAfter;
  final int? showAtMinute;
  final int skipAfterSeconds;
  final bool isActive;

  Ad({
    required this.id,
    required this.type,
    required this.title,
    this.description = '',
    this.imageUrl,
    this.videoUrl,
    required this.targetUrl,
    this.interval = 6,
    this.startAfter = 0,
    this.showAtMinute,
    this.skipAfterSeconds = 5,
    this.isActive = true,
  });

  factory Ad.fromJson(Map<String, dynamic> j) {
    return Ad(
      id: j['id'] is int ? j['id'] : int.tryParse(j['id'].toString()) ?? 0,
      type: j['type']?.toString() ?? 'feed',
      title: j['title']?.toString() ?? '',
      description: j['description']?.toString() ?? '',
      imageUrl: j['image_url']?.toString(),
      videoUrl: j['video_url']?.toString(),
      targetUrl: j['target_url']?.toString() ?? '',
      interval: j['interval'] is int ? j['interval'] : int.tryParse(j['interval'].toString()) ?? 6,
      startAfter: j['start_after'] is int ? j['start_after'] : int.tryParse(j['start_after'].toString()) ?? 0,
      showAtMinute: j['show_at_minute'] is int ? j['show_at_minute'] : (j['show_at_minute'] != null ? int.tryParse(j['show_at_minute'].toString()) : null),
      skipAfterSeconds: j['skip_after_seconds'] is int ? j['skip_after_seconds'] : int.tryParse(j['skip_after_seconds'].toString()) ?? 5,
      isActive: j['is_active'] == true || j['is_active'] == 1 || j['is_active'] == '1',
    );
  }
}
