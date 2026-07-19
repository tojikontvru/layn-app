import 'dart:io';
import 'package:html/parser.dart' as html_parser;

String abs(String url) {
  if (url.isEmpty) return url;
  if (url.startsWith('http')) return url;
  if (url.startsWith('//')) return 'https:$url';
  return 'https://layn.su$url';
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
        thumbnailUrl: j['thumbnail_url'] ?? j['thumb'] ?? '',
        videoUrl: j['video_url'] ?? '',
        username: j['username'] ?? '',
        views: j['views'] ?? 0,
        duration: j['duration'] ?? '',
        createdAt: j['created_at'] ?? '',
        isShorts: j['is_shorts_video'] ?? false,
        channelName: j['channel_name'] ?? j['firstname'],
        avatar: j['avatar'],
        commentsCount: j['comments_count'],
      );
}

class VideoUser {
  final String? username;
  final String? channelName;
  final String? avatar;
  VideoUser({this.username, this.channelName, this.avatar});
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
                username: j['user']['username'],
                channelName: j['user']['channel_name'],
                avatar: j['user']['avatar'])
            : null,
      );
}

class Short {
  final int id;
  final String title;
  final String videoUrl;
  final String thumbnailUrl;
  final int views;

  Short({
    required this.id,
    required this.title,
    required this.videoUrl,
    this.thumbnailUrl = '',
    this.views = 0,
  });

  static List<Short> fromResponse(Map<String, dynamic> resp) {
    final data = resp['data'];
    if (data == null) return [];

    // Case 1: data.videos is a JSON array
    final videos = data['videos'];
    if (videos is List) {
      return videos.asMap().entries.map((e) {
        final j = e.value as Map<String, dynamic>;
        return Short(
          id: j['id'] ?? e.key + 1,
          title: j['title'] ?? '',
          videoUrl: abs(j['video_url'] ?? ''),
          thumbnailUrl: abs(j['thumbnail_url'] ?? j['thumb'] ?? ''),
          views: j['views'] ?? 0,
        );
      }).toList();
    }

    // Case 2: data.videos is HTML string — parse it
    if (videos is String && videos.isNotEmpty) {
      return _parseHtml(videos);
    }

    return [];
  }

  static List<Short> _parseHtml(String html) {
    final doc = html_parser.parse(html);
    final shorts = <Short>[];
    int idx = 0;

    // Strategy: find all <video> tags with src/source
    for (final v in doc.querySelectorAll('video')) {
      final src = v.querySelector('source')?.attributes['src'] ??
          v.attributes['src'] ??
          '';
      if (src.isEmpty) continue;

      String title = '';
      String poster = v.attributes['poster'] ?? '';
      int views = 0;

      // Walk parents to find title/views
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

    return shorts;
  }
}
