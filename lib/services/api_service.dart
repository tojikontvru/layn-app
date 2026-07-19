import 'dart:convert';
import 'dart:io';
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
      final list = d['data'] as List? ?? [];
      return list.map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
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
}
