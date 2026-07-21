import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import '../constants.dart';
import '../models/models.dart';

class ApiService {
  static final instance = ApiService._();
  ApiService._();

  String? _token;
  String? get token => _token;

  void setToken(String? t) => _token = t;

  Map<String, String> get _h => {
        'Accept': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Uri _uri(String ep) => Uri.parse('$baseUrl$ep');

  Future<Map<String, dynamic>> get(String ep) async {
    final r = await http.get(_uri(ep), headers: _h);
    if (r.statusCode >= 200 && r.statusCode < 300) {
      return jsonDecode(r.body) as Map<String, dynamic>;
    }
    throw HttpException('HTTP ${r.statusCode}');
  }

  Future<Map<String, dynamic>> post(String ep, {Map<String, dynamic>? body}) async {
    final r = await http.post(_uri(ep),
        headers: {..._h, 'Content-Type': 'application/json'},
        body: body != null ? jsonEncode(body) : null);
    final d = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode >= 200 && r.statusCode < 300) {
      return d;
    }
    // Парсим ошибку сервера (422 и т.д.)
    final msg = d['message'] ?? d['error'] ?? 'HTTP ${r.statusCode}';
    throw Exception(msg);
  }

  // === Home ===
  Future<Map<String, dynamic>> home({int page = 1, String? category}) async {
    var ep = '/home?page=$page';
    if (category != null && category.isNotEmpty) ep += '&category=$category';
    return get(ep);
  }

  // === Categories ===
  Future<List<Category>> categories() async {
    try {
      final d = await get('/categories');
      // API returns: {status: 'success', data: {categories: [...]}}
      final catsData = d['data'];
      if (catsData is Map) {
        final cats = catsData['categories'];
        if (cats is List) {
          return cats.map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
        }
      }
      // Fallback: data is directly a list
      if (catsData is List) {
        return catsData.map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // === Search ===
  Future<List<Video>> search(String q) async {
    final d = await get('/search?q=$q');
    final videos = d['data']?['videos'] as List? ?? d['data'] as List? ?? [];
    return videos
        .map((e) => Video.fromJson(e as Map<String, dynamic>))
        .where((v) => !v.isShorts)
        .toList();
  }

  // === Video detail ===
  Future<Map<String, dynamic>> video(int id) => get('/video/$id');

  // === Comments ===
  Future<List<Comment>> comments(int videoId) async {
    final d = await get('/video/$videoId/comments');
    final list = d['data']?['comments'] as List? ?? d['data'] as List? ?? [];
    return list
        .map((e) => Comment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> sendComment(int videoId, String text) =>
      post('/comment', body: {'video_id': videoId, 'comment': text});

  // === Auth ===
  Future<Map<String, dynamic>> login(String username, String password) async {
    final d = await post('/login', body: {'username': username, 'password': password});
    final t = d['token'] ?? d['data']?['token'];
    if (t != null) _token = t.toString();
    return d;
  }

  Future<Map<String, dynamic>> register(String username, String email, String password) async {
    final d = await post('/register', body: {
      'username': username, 'email': email, 'password': password, 'firstname': username,
    });
    final t = d['data']?['token'] ?? d['token'];
    if (t != null) _token = t.toString();
    return d;
  }

  Future<void> logout() async {
    try { await post('/logout'); } catch (_) {}
    _token = null;
  }

  Future<Map<String, dynamic>> me() => get('/me');

  // === Social (auth required) ===
  Future<Map<String, dynamic>> subscribe(int channelId) =>
      post('/subscribe', body: {'channel_id': channelId});

  Future<Map<String, dynamic>> reaction(int videoId, String type) =>
      post('/reaction', body: {'video_id': videoId, 'reaction': type});

  // === Shorts ===
  Future<List<dynamic>> shorts({int page = 1}) async {
    final r = await http.get(Uri.parse('$shortsUrl?page=$page'), headers: _h);
    if (r.statusCode >= 200 && r.statusCode < 300) {
      final d = jsonDecode(r.body) as Map<String, dynamic>;
      return (d['data']?['shorts'] ?? d['data']?['videos'] ?? []) as List;
    }
    throw HttpException('HTTP ${r.statusCode}');
  }

  /// Загружает шортсы и возвращает Set ID (для исключения с главной)
  Future<Set<int>> shortsIds() async {
    final ids = <int>{};
    try {
      for (int page = 1; page <= 3; page++) {
        final r = await http.get(Uri.parse('$shortsUrl?page=$page'), headers: _h);
        if (r.statusCode != 200) {
          debugPrint('shortsIds page=$page: HTTP ${r.statusCode}');
          break;
        }
        final d = jsonDecode(r.body) as Map<String, dynamic>;
        final shortsList = Short.fromResponse(d);
        debugPrint('shortsIds page=$page: ${shortsList.length} shorts');
        if (shortsList.isEmpty) break;
        for (final s in shortsList) {
          ids.add(s.id);
        }
        final meta = d['data'] ?? {};
        final lastPage = meta['last_page'] ?? 1;
        if (page >= lastPage) break;
      }
    } catch (e) {
      debugPrint('shortsIds error: $e');
    }
    debugPrint('SHORTS IDs total: ${ids.length}');
    return ids;
  }

  // === Profile editing ===
  Future<Map<String, dynamic>> updateProfile({
    String? username,
    String? email,
    String? firstname,
    String? lastname,
    String? channelName,
    String? description,
    String? avatar,
  }) async {
    final body = <String, dynamic>{};
    if (username != null) body['username'] = username;
    if (email != null) body['email'] = email;
    if (firstname != null) body['firstname'] = firstname;
    if (lastname != null) body['lastname'] = lastname;
    if (channelName != null) body['channel_name'] = channelName;
    if (description != null) body['description'] = description;
    if (avatar != null) body['avatar'] = avatar;
    return post('/profile/update', body: body);
  }

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) =>
      post('/profile/password', body: {
        'current_password': currentPassword,
        'password': newPassword,
      });

  // === Subscriptions ===
  Future<List<VideoUser>> subscriptions() async {
    try {
      final d = await get('/subscriptions');
      final data = d['data'];
      if (data is Map) {
        final subs = data['subscriptions'] ?? data['channels'] ?? data['users'];
        if (subs is List) {
          return subs.map((e) => VideoUser.fromJson(e as Map<String, dynamic>)).toList();
        }
      }
      if (data is List) {
        return data.map((e) => VideoUser.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<List<Video>> subscriptionFeed({int page = 1}) async {
    try {
      final d = await get('/subscriptions/feed?page=$page');
      final data = d['data'];
      List list;
      if (data is Map) {
        list = data['videos'] ?? data['feed'] ?? [];
      } else if (data is List) {
        list = data;
      } else {
        return [];
      }
      return list
          .map((e) => Video.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // === Watch history ===
  Future<List<Video>> history({int page = 1}) async {
    try {
      final d = await get('/history?page=$page');
      final data = d['data'];
      List list;
      if (data is Map) {
        list = data['videos'] ?? data['history'] ?? [];
      } else if (data is List) {
        list = data;
      } else {
        return [];
      }
      return list
          .map((e) => Video.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // === Liked videos ===
  Future<List<Video>> likedVideos({int page = 1}) async {
    try {
      final d = await get('/likes?page=$page');
      final data = d['data'];
      List list;
      if (data is Map) {
        list = data['videos'] ?? data['likes'] ?? [];
      } else if (data is List) {
        list = data;
      } else {
        return [];
      }
      return list
          .map((e) => Video.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
