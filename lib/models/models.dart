import 'package:flutter/foundation.dart' show debugPrint;
import 'package:intl/intl.dart';
import 'package:html/parser.dart' as html_parser;

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
  final String title;
  final String description;
  final String thumbnailUrl;
  final String videoUrl;
  final String username;
  final int views;
  final String duration;
  final String createdAt;
  final bool isShorts;
  final String? channelName;
  final String? avatar;
  final int? commentsCount;
  final String? categorySlug;

  Video({
    required this.id,
    required this.title,
    this.description = '',
    required this.thumbnailUrl,
    required this.videoUrl,
    required this.username,
    this.views = 0,
    this.duration = '',
    this.createdAt = '',
    this.isShorts = false,
    this.channelName,
    this.avatar,
    this.commentsCount,
    this.categorySlug,
  });

  String get thumb => abs(thumbnailUrl);
  String get channel => channelName ?? username;

  VideoUser? get user => username.isNotEmpty
      ? VideoUser(username: username, channelName: channelName, avatar: avatar)
      : null;

  factory Video.fromJson(Map<String, dynamic> j) => Video(
        id: j['id'] ?? 0,
        title: j['title'] ?? '',
        description: j['description'] ?? '',
        thumbnailUrl: j['thumb'] ?? j['thumbnail_url'] ?? '',
        videoUrl: j['video_url'] ?? '',
        username: j['user']?['username'] ?? j['username'] ?? '',
        views: j['views'] ?? 0,
        duration: j['duration'] ?? '',
        createdAt: j['created_at'] ?? '',
        isShorts: (j['is_shorts'] ?? j['is_shorts_video'] ?? 0) == 1,
        channelName: j['user']?['channel_name'] ?? j['channel_name'] ?? j['firstname'],
        avatar: abs(j['user']?['avatar'] ?? j['avatar'] ?? ''),
        commentsCount: j['comments_count'],
        categorySlug: j['category']?['slug'] ?? j['category_slug'] ?? j['slug'],
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

class Short {
  final int id;
  final String title;
  final String videoUrl;
  final String thumbnailUrl;
  final int views;
  final String username;
  final String avatar;
  final String channelName;

  Short({
    required this.id,
    required this.title,
    required this.videoUrl,
    this.thumbnailUrl = '',
    this.views = 0,
    this.username = '',
    this.avatar = '',
    this.channelName = '',
  });

  static List<Short> fromResponse(Map<String, dynamic> resp) {
    final data = resp['data'];
    if (data == null) return [];

    // API /api/v1/shorts returns {data: {shorts: [...]}}
    final videos = data['shorts'] ?? data['videos'];
    if (videos is List) {
      return videos.asMap().entries.map((e) {
        final j = e.value as Map<String, dynamic>;
        // videoData() returns user as nested object
        final user = j['user'];
        return Short(
          id: j['id'] ?? e.key + 1,
          title: j['title'] ?? '',
          videoUrl: abs(j['video_url'] ?? ''),
          thumbnailUrl: abs(j['thumb'] ?? j['thumbnail_url'] ?? ''),
          views: j['views'] ?? 0,
          username: user?['username'] ?? j['username'] ?? '',
          avatar: abs(user?['avatar'] ?? j['avatar'] ?? ''),
          channelName: user?['channel_name'] ?? j['channel_name'] ?? '',
        );
      }).toList();
    }

    if (videos is String && videos.isNotEmpty) {
      return _parseHtml(videos);
    }

    return [];
  }

  static List<Short> _parseHtml(String html) {
    final doc = html_parser.parse(html);
    final shorts = <Short>[];
    final seenUrls = <String>{};
    int idx = 0;

    // Strategy 1: <video> tags
    for (final v in doc.querySelectorAll('video')) {
      final src = v.querySelector('source')?.attributes['src'] ??
          v.attributes['src'] ??
          '';
      if (src.isEmpty || seenUrls.contains(src)) continue;
      seenUrls.add(src);

      String title = '';
      String poster = v.attributes['poster'] ?? '';
      int views = 0;

      var el = v.parent;
      for (var i = 0; i < 5 && el != null; i++, el = el.parent) {
        if (title.isEmpty) {
          final h = el.querySelector('h5,h4,h3,.title,.short-title');
          if (h != null) title = h.text.trim();
        }
        if (views == 0) {
          final vm = RegExp(r'(\d[\d\s]*)').firstMatch(el.text);
          if (vm != null) views = int.tryParse(vm.group(1)!.replaceAll(' ', '')) ?? 0;
        }
      }

      shorts.add(Short(
        id: ++idx,
        title: title,
        videoUrl: abs(src),
        thumbnailUrl: abs(poster),
        views: views,
      ));
    }

    // Strategy 2: <a> tags with video href
    for (final a in doc.querySelectorAll('a[href]')) {
      final href = a.attributes['href'] ?? '';
      if (!RegExp(r'\.(mp4|mov|m3u8|webm)(\?|$)', caseSensitive: false).hasMatch(href)) continue;
      if (seenUrls.contains(href)) continue;
      seenUrls.add(href);

      String title = a.attributes['title'] ?? a.text.trim();
      int views = 0;
      final vm = RegExp(r'(\d[\d\s]*)').firstMatch(a.text);
      if (vm != null) views = int.tryParse(vm.group(1)!.replaceAll(' ', '')) ?? 0;

      shorts.add(Short(
        id: ++idx,
        title: title,
        videoUrl: abs(href),
        thumbnailUrl: '',
        views: views,
      ));
    }

    // Strategy 3: <source> tags (outside <video>)
    for (final s in doc.querySelectorAll('source[src]')) {
      final src = s.attributes['src'] ?? '';
      if (!RegExp(r'\.(mp4|mov|m3u8|webm)(\?|$)', caseSensitive: false).hasMatch(src)) continue;
      if (seenUrls.contains(src)) continue;
      seenUrls.add(src);
      shorts.add(Short(
        id: ++idx,
        title: '',
        videoUrl: abs(src),
        thumbnailUrl: '',
        views: 0,
      ));
    }

    // Strategy 4: Any element with data-video or data-src attributes
    for (final el in doc.querySelectorAll('[data-video],[data-src],[data-url]')) {
      final videoUrl = el.attributes['data-video'] ??
          el.attributes['data-src'] ??
          el.attributes['data-url'] ??
          '';
      if (videoUrl.isEmpty || seenUrls.contains(videoUrl)) continue;
      seenUrls.add(videoUrl);
      String title = el.attributes['title'] ?? el.text.trim();
      if (title.length > 100) title = title.substring(0, 100);
      shorts.add(Short(
        id: ++idx,
        title: title,
        videoUrl: abs(videoUrl),
        thumbnailUrl: abs(el.attributes['data-thumb'] ?? el.attributes['data-poster'] ?? ''),
        views: 0,
      ));
    }

    debugPrint('HTML parsed: ${shorts.length} shorts from HTML');
    return shorts;
  }
}
