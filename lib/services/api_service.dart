import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../constants.dart';
import '../models/models.dart';

class ApiService {
  ApiService._();
  static final instance = ApiService._();

  String? _token;

  void setToken(String? token) {
    _token = token ?? authToken;
  }

  Map<String, String> get _headers {
    final h = <String, String>{
      'Accept': 'application/json',
    };
    if (_token != null) h['Authorization'] = 'Bearer $_token';
    return h;
  }

  Future<Map<String, dynamic>> get(String endpoint) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw HttpException('HTTP ${response.statusCode}: ${response.body}');
  }

  Future<Map<String, dynamic>> post(String endpoint, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final response = await http.post(uri, headers: _headers, body: body != null ? jsonEncode(body) : null);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw HttpException('HTTP ${response.statusCode}: ${response.body}');
  }

  // Auth
  Future<Map<String, dynamic>> login(String username, String password) async {
    final data = await post('/login', body: {'username': username, 'password': password});
    final token = data['data']?['token'] ?? data['token'];
    if (token != null) _token = token.toString();
    return data;
  }

  Future<Map<String, dynamic>> register(String username, String email, String password, String firstname) async {
    final data = await post('/register', body: {
      'username': username,
      'email': email,
      'password': password,
      'firstname': firstname,
    });
    final token = data['data']?['token'] ?? data['token'];
    if (token != null) _token = token.toString();
    return data;
  }

  Future<void> logout() async {
    try { await post('/logout'); } catch (_) {}
    _token = null;
  }

  Future<VideoUser?> me() async {
    try {
      final data = await get('/user/profile');
      final u = data['data'] ?? data['user'];
      if (u == null) return null;
      return VideoUser(
        username: u['username'] ?? '',
        channelName: u['channel_name'] ?? u['firstname'],
        avatar: u['avatar'],
      );
    } catch (_) {
      return null;
    }
  }

  // Comments
  Future<List<Comment>> comments(int videoId) async {
    try {
      final data = await get('/video/$videoId/comments');
      final list = data['data']?['comments'] ?? data['data'] ?? [];
      return (list as List? ?? []).map((e) => Comment.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> comment(int videoId, String text) async {
    await post('/video/$videoId/comment', body: {'comment': text});
  }

  // Subscribe
  Future<void> subscribe(int userId) async {
    await post('/user/$userId/subscribe');
  }

  // Home
  Future<Map<String, dynamic>> home({int page = 1}) async {
    return get('/home?page=$page');
  }

  // Shorts — отдельный URL, НЕ через baseUrl
  Future<Map<String, dynamic>> shorts({int page = 1}) async {
    final uri = Uri.parse('https://layn.su/load-shorts?page=$page');
    final response = await http.get(uri, headers: {'Accept': 'application/json'});
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw HttpException('HTTP ${response.statusCode}: ${response.body}');
  }
}
