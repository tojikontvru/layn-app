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
    if (r.statusCode >= 200 && r.statusCode < 300) {
      return jsonDecode(r.body) as Map<String, dynamic>;
    }
    throw HttpException('HTTP ${r.statusCode}');
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
      // Try different response structures
      dynamic raw = d['data'] ?? d['categories'] ?? d;
      if (raw is Map) {
        // Could be {data: {categories: [...]}} or flat map
        raw = raw['categories'] ?? raw['data'] ?? raw.values.firstWhere((v) => v is List, orElse: () => []);
      }
      if (raw is List) {
        return raw.map((e) {
          if (e is Map<String, dynamic>) return Category.fromJson(e);
          return Category(id: 0, name: e.toString(), slug: '');
        }).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // === Search ===
  Future<List<Video>> search(String q) async {
    final d = await get('/search?q=$q');
    return (d['data'] as List? ?? [])
        .map((e) => Video.fromJson(e as Map<String, dynamic>))
        .where((v) => !v.isShorts)
        .toList();
  }

  // === Video detail ===
  Future<Map<String, dynamic>> video(int id) => get('/video/$id');

  // === Comments ===
  Future<List<Comment>> comments(int videoId) async {
    final d = await get('/video/$videoId/comments');
    return (d['data'] as List? ?? [])
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

  Future<Map<String, dynamic>> register(String username, String email, String password, String name) async {
    final d = await post('/register', body: {
      'username': username, 'email': email, 'password': password, 'firstname': name,
    });
    final t = d['token'] ?? d['data']?['token'];
    if (t != null) _token = t.toString();
    return d;
  }

  Future<void> logout() async {
    try { await post('/logout'); } catch (_) {}
    _token = null;
  }

  Future<Map<String, dynamic>> me() => get('/me');

  // === Social ===
  Future<void> subscribe(String username) => post('/subscribe', body: {'username': username});
  Future<void> reaction(int videoId, String type) => post('/reaction', body: {'video_id': videoId, 'type': type});

  // === Shorts ===
  Future<List<dynamic>> shorts({int page = 1}) async {
    final r = await http.get(Uri.parse('$shortsUrl?page=$page'), headers: {'Accept': 'application/json'});
    if (r.statusCode >= 200 && r.statusCode < 300) {
      final d = jsonDecode(r.body) as Map<String, dynamic>;
      return (d['data']?['videos'] as List?) ?? [];
    }
    throw HttpException('HTTP ${r.statusCode}');
  }

  /// Загружает шортсы и возвращает Set URL видео (для исключения с главной)
  Future<Set<String>> shortsUrls() async {
    final urls = <String>{};
    try {
      for (int page = 1; page <= 3; page++) {
        final r = await http.get(
          Uri.parse('$shortsUrl?page=$page'),
          headers: {'Accept': 'application/json'},
        );
        if (r.statusCode != 200) break;
        final d = jsonDecode(r.body) as Map<String, dynamic>;
        final shorts = Short.fromResponse(d);
        if (shorts.isEmpty) break;
        for (final s in shorts) {
          if (s.videoUrl.isNotEmpty) urls.add(s.videoUrl);
        }
        final meta = d['data'] ?? {};
        final lastPage = meta['last_page'] ?? 1;
        if (page >= lastPage) break;
      }
    } catch (_) {}
    debugPrint('SHORTS URLs loaded: ${urls.length}');
    return urls;
  }
}
