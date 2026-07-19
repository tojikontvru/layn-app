class User {
  final int id;
  final String username;
  final String? channelName;
  final String? avatar;
  final String? email;
  final int? subscribers;
  final int? videosCount;

  User({
    required this.id,
    required this.username,
    this.channelName,
    this.avatar,
    this.email,
    this.subscribers,
    this.videosCount,
  });

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'] ?? 0,
        username: j['username'] ?? '',
        channelName: j['channel_name'],
        avatar: j['avatar'],
        email: j['email'],
        subscribers: j['subscribers'],
        videosCount: j['videos_count'],
      );
}

class Video {
  final int id;
  final String title;
  final String slug;
  final String videoUrl;
  final String thumb;
  final int views;
  final String? duration;
  final int? commentsCount;
  final User? user;
  final int? categoryId;
  final bool isShorts;

  Video({
    required this.id,
    required this.title,
    required this.slug,
    required this.videoUrl,
    required this.thumb,
    required this.views,
    this.duration,
    this.commentsCount,
    this.user,
    this.categoryId,
    this.isShorts = false,
  });

  factory Video.fromJson(Map<String, dynamic> j) => Video(
        id: j['id'] ?? 0,
        title: j['title'] ?? '',
        slug: j['slug'] ?? '',
        videoUrl: j['video_url'] ?? '',
        thumb: j['thumb'] ?? '',
        views: j['views'] ?? 0,
        duration: j['duration'],
        commentsCount: j['comments_count'],
        user: j['user'] != null ? User.fromJson(j['user']) : null,
        categoryId: j['category_id'],
        isShorts: j['is_shorts_video'] == 1 || j['is_shorts_video'] == true,
      );
}

class Comment {
  final int id;
  final String comment;
  final User? user;

  Comment({required this.id, required this.comment, this.user});

  factory Comment.fromJson(Map<String, dynamic> j) => Comment(
        id: j['id'] ?? 0,
        comment: j['comment'] ?? '',
        user: j['user'] != null ? User.fromJson(j['user']) : null,
      );
}

class Category {
  final int id;
  final String name;
  final String? slug;
  final int? count;

  Category({required this.id, required this.name, this.slug, this.count});

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: j['id'] ?? 0,
        name: j['name'] ?? '',
        slug: j['slug'],
        count: j['videos_count'],
      );
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}
