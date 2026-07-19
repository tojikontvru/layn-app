import 'dart:io';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;

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

  /// User info shorthand
  VideoUser? get user => (username.isNotEmpty || (channelName?.isNotEmpty ?? false))
      ? VideoUser(username: username, channelName: channelName, avatar: avatar)
      : null;

  String get thumb => thumbnailUrl;

  factory Video.fromJson(Map<String, dynamic> json) {
    return Video(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      thumbnailUrl: json['thumbnail_url'] ?? '',
      videoUrl: json['video_url'] ?? '',
      username: json['username'] ?? '',
      views: json['views'] ?? 0,
      duration: json['duration'] ?? '00:00',
      createdAt: json['created_at'] ?? '',
      isShortsVideo: json['is_shorts_video'] ?? false,
      channelName: json['channel_name'],
      avatar: json['avatar'],
      commentsCount: json['comments_count'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'thumbnail_url': thumbnailUrl,
        'video_url': videoUrl,
        'username': username,
        'views': views,
        'duration': duration,
        'created_at': createdAt,
        'is_shorts_video': isShortsVideo,
        'channel_name': channelName,
        'avatar': avatar,
        'comments_count': commentsCount,
      };
}

/// User info for video cards
class VideoUser {
  final String? username;
  final String? channelName;
  final String? avatar;

  VideoUser({this.username, this.channelName, this.avatar});
}

/// Comment model
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
  final String? duration;
  final String? channelName;

  Short({
    required this.id,
    required this.title,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.username,
    required this.views,
    this.duration,
    this.channelName,
  });

  /// Parse shorts from HTML returned by /load-shorts
  /// The API returns: { status: "success", data: { videos: "<html>...</html>" } }
  static List<Short> parseFromHtml(Map<String, dynamic> response) {
    final data = response['data'];
    if (data == null) return [];

    final htmlContent = data['videos'] ?? '';
    if (htmlContent is! String || htmlContent.isEmpty) return [];

    final document = html_parser.parse(htmlContent);
    final shorts = <Short>[];

    // Each short is a <div class="short-item"> or similar container
    // with a <video> tag and title/views info
    final shortItems = document.querySelectorAll('.short-item, .short-card, .col-6, .col-md-3, [class*="short"]');

    if (shortItems.isEmpty) {
      // Fallback: try to find video tags directly
      final videoTags = document.querySelectorAll('video');
      for (var i = 0; i < videoTags.length; i++) {
        final videoTag = videoTags[i];
        final sourceTag = videoTag.querySelector('source');
        final videoUrl = sourceTag?.attributes['src'] ?? videoTag.attributes['src'] ?? '';

        if (videoUrl.isEmpty) continue;

        // Try to find parent container for title/views
        final parent = videoTag.parent;
        final title = _extractText(parent, '.short-title, .video-title, h5, h4, .title');
        final viewsText = _extractText(parent, '.views, .view-count, .short-view, span');
        final views = _parseViews(viewsText);

        shorts.add(Short(
          id: i + 1,
          title: title,
          videoUrl: _makeAbsoluteUrl(videoUrl),
          thumbnailUrl: '',
          username: '',
          views: views,
        ));
      }
      return shorts;
    }

    for (var i = 0; i < shortItems.length; i++) {
      final item = shortItems[i];

      // Find video source
      final sourceTag = item.querySelector('video source, video');
      String videoUrl = '';
      if (sourceTag != null) {
        videoUrl = sourceTag.attributes['src'] ?? '';
        if (videoUrl.isEmpty && sourceTag.tagName.toLowerCase() == 'video') {
          videoUrl = sourceTag.attributes['src'] ?? '';
        }
      }

      // Find poster/thumbnail
      final videoTag = item.querySelector('video');
      final thumbnailUrl = videoTag?.attributes['poster'] ?? '';

      // Find title
      final title = _extractText(item, '.short-title, .video-title, h5, h4, .title, a[title]');

      // Find views
      final viewsText = _extractText(item, '.views, .view-count, .short-view, .fa-eye + span, span');
      final views = _parseViews(viewsText);

      // Find username/channel
      final username = _extractText(item, '.channel-name, .username, .user-name, a[href*="/"]');

      if (videoUrl.isNotEmpty) {
        shorts.add(Short(
          id: i + 1,
          title: title,
          videoUrl: _makeAbsoluteUrl(videoUrl),
          thumbnailUrl: _makeAbsoluteUrl(thumbnailUrl),
          username: username,
          views: views,
        ));
      }
    }

    return shorts;
  }

  static String _extractText(dom.Element? parent, String selectors) {
    if (parent == null) return '';
    final parts = selectors.split(',');
    for (final selector in parts) {
      final el = parent.querySelector(selector.trim());
      if (el != null) {
        final text = el.text.trim();
        if (text.isNotEmpty) return text;
      }
    }
    return '';
  }

  static int _parseViews(String text) {
    if (text.isEmpty) return 0;
    final cleaned = text.replaceAll(RegExp(r'[^\dKkMm]'), '').trim();
    if (cleaned.isEmpty) return 0;
    try {
      if (cleaned.toUpperCase().endsWith('K')) {
        return (double.parse(cleaned.substring(0, cleaned.length - 1)) * 1000).toInt();
      }
      if (cleaned.toUpperCase().endsWith('M')) {
        return (double.parse(cleaned.substring(0, cleaned.length - 1)) * 1000000).toInt();
      }
      return int.parse(RegExp(r'\d+').firstMatch(text)?.group(0) ?? '0');
    } catch (_) {
      return 0;
    }
  }

  static String _makeAbsoluteUrl(String url) {
    if (url.isEmpty) return url;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('//')) return 'https:$url';
    return 'https://layn.su$url';
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
