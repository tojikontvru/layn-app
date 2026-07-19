import 'dart:io';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;

String _abs(String url) {
  if (url.isEmpty) return url;
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  if (url.startsWith('//')) return 'https:$url';
  return 'https://layn.su$url';
}

/// Video model for regular horizontal videos
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
  final bool isShortsVideo;
  final String? channelName;
  final String? avatar;
  final int? commentsCount;

  Video({
    required this.id,
    required this.title,
    required this.description,
    required this.thumbnailUrl,
    required this.videoUrl,
    required this.username,
    required this.views,
    required this.duration,
    required this.createdAt,
    required this.isShortsVideo,
    this.channelName,
    this.avatar,
    this.commentsCount,
  });

  VideoUser? get user => (username.isNotEmpty || (channelName?.isNotEmpty ?? false))
      ? VideoUser(username: username, channelName: channelName, avatar: avatar)
      : null;

  String get thumb => _abs(thumbnailUrl);

  factory Video.fromJson(Map<String, dynamic> json) {
    return Video(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      thumbnailUrl: json['thumbnail_url'] ?? json['thumb'] ?? '',
      videoUrl: json['video_url'] ?? '',
      username: json['username'] ?? '',
      views: json['views'] ?? 0,
      duration: json['duration'] ?? '00:00',
      createdAt: json['created_at'] ?? '',
      isShortsVideo: json['is_shorts_video'] ?? false,
      channelName: json['channel_name'] ?? json['firstname'],
      avatar: json['avatar'],
      commentsCount: json['comments_count'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'thumbnail_url': thumbnailUrl,
        'video_url': videoUrl,
        'username': username,
        'views': views,
      };
}

class VideoUser {
  final String? username;
  final String? channelName;
  final String? avatar;

  VideoUser({this.username, this.channelName, this.avatar});
}

class Comment {
  final int id;
  final String comment;
  final VideoUser? user;

  Comment({required this.id, required this.comment, this.user});

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] ?? 0,
      comment: json['comment'] ?? '',
      user: json['user'] != null
          ? VideoUser(
              username: json['user']['username'],
              channelName: json['user']['channel_name'],
              avatar: json['user']['avatar'],
            )
          : null,
    );
  }
}

/// Short video model — parsed from HTML in /load-shorts response
class Short {
  final int id;
  final String title;
  final String videoUrl;
  final String thumbnailUrl;
  final String username;
  final int views;

  Short({
    required this.id,
    required this.title,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.username,
    required this.views,
  });

  /// Parse shorts from HTML returned by /load-shorts
  /// API: { status: "success", data: { videos: "<html>...</html>" } }
  static List<Short> parseFromHtml(Map<String, dynamic> response) {
    final data = response['data'];
    if (data == null) return [];

    final htmlContent = data['videos'] ?? '';
    if (htmlContent is! String || htmlContent.isEmpty) return [];

    final document = html_parser.parse(htmlContent);
    final shorts = <Short>[];
    final seen = <String>{};

    // Strategy 1: find <video> tags — the most reliable
    final videoTags = document.querySelectorAll('video');
    for (var i = 0; i < videoTags.length; i++) {
      final vtag = videoTags[i];
      final source = vtag.querySelector('source');
      String vurl = source?.attributes['src'] ?? vtag.attributes['src'] ?? '';
      String poster = vtag.attributes['poster'] ?? '';

      if (vurl.isEmpty) continue;
      if (seen.contains(vurl)) continue;
      seen.add(vurl);

      // Walk up to find title, views in parent elements
      dom.Element? parent = vtag.parent;
      String title = '';
      int views = 0;
      for (var depth = 0; depth < 5 && parent != null; depth++) {
        if (title.isEmpty) {
          final h = parent.querySelector('h5, h4, h3, .title, .short-title, a[title]');
          if (h != null) title = h.text.trim();
          if (title.isEmpty) title = parent.attributes['title'] ?? '';
        }
        if (views == 0) {
          final vEl = parent.querySelector('.views, .view-count, .fa-eye, [class*="view"]');
          if (vEl != null) {
            final m = RegExp(r'(\d+)').firstMatch(vEl.text);
            if (m != null) views = int.tryParse(m.group(1) ?? '0') ?? 0;
          }
        }
        parent = parent.parent;
      }

      shorts.add(Short(
        id: i + 1,
        title: title,
        videoUrl: _abs(vurl),
        thumbnailUrl: _abs(poster),
        username: '',
        views: views,
      ));
    }

    // Strategy 2: find <a> tags with video links
    if (shorts.isEmpty) {
      final links = document.querySelectorAll('a[href]');
      for (var i = 0; i < links.length; i++) {
        final a = links[i];
        final href = a.attributes['href'] ?? '';
        if (!href.contains('/video/') && !href.contains('/shorts/')) continue;

        final img = a.querySelector('img');
        String thumbnail = img?.attributes['src'] ?? img?.attributes['data-src'] ?? '';
        String title = a.attributes['title'] ?? '';
        if (title.isEmpty) {
          final h = a.querySelector('h5, h4, h3, .title');
          if (h != null) title = h.text.trim();
        }

        if (thumbnail.isNotEmpty && !seen.contains(href)) {
          seen.add(href);
          shorts.add(Short(
            id: i + 1,
            title: title,
            videoUrl: _abs(href),
            thumbnailUrl: _abs(thumbnail),
            username: '',
            views: 0,
          ));
        }
      }
    }

    // Strategy 3: find <img> tags as thumbnails
    if (shorts.isEmpty) {
      final imgs = document.querySelectorAll('img[src]');
      for (var i = 0; i < imgs.length; i++) {
        final img = imgs[i];
        final src = img.attributes['src'] ?? '';
        if (src.isEmpty || seen.contains(src)) continue;
        // Skip small images (icons, avatars)
        final width = int.tryParse(img.attributes['width'] ?? '0') ?? 0;
        final height = int.tryParse(img.attributes['height'] ?? '0') ?? 0;
        if ((width > 0 && width < 100) || (height > 0 && height < 100)) continue;
        if (!src.contains('.jpg') && !src.contains('.png') && !src.contains('.webp') && !src.contains('thumb') && !src.contains('poster')) continue;

        seen.add(src);
        final parent = img.parent;
        String title = parent?.attributes['title'] ?? '';
        if (title.isEmpty) {
          final h = parent?.querySelector('h5, h4, .title');
          if (h != null) title = h.text.trim();
        }

        shorts.add(Short(
          id: i + 1,
          title: title,
          videoUrl: '',
          thumbnailUrl: _abs(src),
          username: '',
          views: 0,
        ));
      }
    }

    return shorts;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'video_url': videoUrl,
        'thumbnail_url': thumbnailUrl,
        'username': username,
        'views': views,
      };
}
