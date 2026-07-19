import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../constants.dart';

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

  // === API Methods ===

  Future<Map<String, dynamic>> home({int page = 1}) => get('/home?page=$page');

  Future<Map<String, dynamic>> videos({int page = 1}) => get('/videos?page=$page');

  Future<Map<String, dynamic>> video(int id) => get('/video/$id');

  Future<List<dynamic>> categories() async {
    final d = await get('/categories');
    return (d['data'] as List?) ?? [];
  }

  Future<Map<String, dynamic>> search(String q) => get('/search?q=$q');

  Future<Map<String, dynamic>> channel(String username) => get('/channel/$username');

  Future<List<dynamic>> comments(int videoId) async {
    final d = await get('/video/$videoId/comments');
    return (d['data'] as List?) ?? [];
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    final d = await post('/login', body: {'username': username, 'password': password});
    final t = d['token'] ?? d['data']?['token'];
    if (t != null) _token = t.toString();
    return d;
  }

  Future<Map<String, dynamic>> register(String username, String email, String password, String name) async {
    final d = await post('/register', body: {
      'username': username,
      'email': email,
      'password': password,
      'firstname': name,
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

  Future<void> subscribe(String username) => post('/subscribe', body: {'username': username});

  Future<void> reaction(int videoId, String type) => post('/reaction', body: {'video_id': videoId, 'type': type});

  Future<void> sendComment(int videoId, String text) => post('/comment', body: {'video_id': videoId, 'comment': text});

  // Shorts — отдельный URL
  Future<List<dynamic>> shorts({int page = 1}) async {
    final r = await http.get(Uri.parse('$shortsUrl?page=$page'), headers: {'Accept': 'application/json'});
    if (r.statusCode >= 200 && r.statusCode < 300) {
      final d = jsonDecode(r.body) as Map<String, dynamic>;
      return (d['data']?['videos'] as List?) ?? [];
    }
    throw HttpException('HTTP ${r.statusCode}');
  }
}
