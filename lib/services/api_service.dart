import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';
import '../models/models.dart';

class ApiService {
  final String _base = baseUrl;
  String? _token;

  void setToken(String? token) => _token = token;
  String? get token => _token;

  Map<String, String> get _headers {
    final h = {'Accept': 'application/json'};
    if (_token != null) h['Authorization'] = 'Bearer $_token';
    return h;
  }

  dynamic _parse(http.Response r) {
    dynamic body;
    try {
      body = json.decode(r.body);
    } catch (_) {
      throw ApiException('Ошибка разбора ответа');
    }
    if (r.statusCode >= 200 && r.statusCode < 300) {
      if (body is! Map || !body.containsKey('data')) {
        throw ApiException('Некорректный ответ сервера');
      }
      return body;
    }
    final msg = (body is Map && body['message'] != null)
        ? body['message'].toString()
        : 'Ошибка запроса (${r.statusCode})';
    throw ApiException(msg);
  }

  /* ---------- Public ---------- */

  Future<Map<String, dynamic>> home({int page = 1}) async {
    final r = await http.get(Uri.parse('$_base/home?page=$page'), headers: _headers);
    final b = _parse(r);
    return (b['data'] as Map<String, dynamic>? ?? {});
  }

  Future<List<Video>> shorts({int page = 1}) async {
    final r = await http.get(Uri.parse('$_base/shorts?page=$page'), headers: _headers);
    final b = _parse(r);
    final data = (b['data'] as Map<String, dynamic>? ?? {});
    final list = (data['shorts'] as List? ?? []);
    return list.map((e) => Video.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Video>> allVideos() async {
    final r = await http.get(Uri.parse('$_base/videos/all'), headers: _headers);
    final b = _parse(r);
    final data = (b['data'] as Map<String, dynamic>? ?? {});
    final list = (data['videos'] as List? ?? []);
    return list.map((e) => Video.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Video>> videos({int page = 1, int? categoryId, String? sort, int? type}) async {
    final q = <String, String>{'page': '$page'};
    if (categoryId != null) q['category_id'] = '$categoryId';
    if (sort != null) q['sort'] = sort;
    if (type != null) q['type'] = '$type';
    final r = await http.get(Uri.parse('$_base/videos').replace(queryParameters: q), headers: _headers);
    final b = _parse(r);
    final data = (b['data'] as Map<String, dynamic>? ?? {});
    final list = (data['videos'] as List? ?? []);
    return list.map((e) => Video.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Video>> search(String q, {int page = 1}) async {
    final r = await http.get(Uri.parse('$_base/search?q=${Uri.encodeComponent(q)}&page=$page'), headers: _headers);
    final b = _parse(r);
    final data = (b['data'] as Map<String, dynamic>? ?? {});
    final list = (data['videos'] as List? ?? []);
    return list.map((e) => Video.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Category>> categories() async {
    final r = await http.get(Uri.parse('$_base/categories'), headers: _headers);
    final b = _parse(r);
    final data = (b['data'] as Map<String, dynamic>? ?? {});
    final list = (data['categories'] as List? ?? []);
    return list.map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Video> videoDetail(int id) async {
    final r = await http.get(Uri.parse('$_base/video/$id'), headers: _headers);
    final b = _parse(r);
    final data = (b['data'] as Map<String, dynamic>? ?? {});
    return Video.fromJson(data);
  }

  Future<Map<String, dynamic>> channel(String username, {int page = 1}) async {
    final r = await http.get(Uri.parse('$_base/channel/$username?page=$page'), headers: _headers);
    final b = _parse(r);
    return (b['data'] as Map<String, dynamic>? ?? {});
  }

  Future<List<Comment>> comments(int id) async {
    final r = await http.get(Uri.parse('$_base/video/$id/comments'), headers: _headers);
    final b = _parse(r);
    final data = (b['data'] as Map<String, dynamic>? ?? {});
    final list = (data['comments'] as List? ?? []);
    return list.map((e) => Comment.fromJson(e as Map<String, dynamic>)).toList();
  }

  /* ---------- Auth ---------- */

  Future<Map<String, dynamic>> login(String username, String password) async {
    final r = await http.post(Uri.parse('$_base/login'),
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: json.encode({'username': username, 'password': password}));
    final b = _parse(r);
    final data = (b['data'] as Map<String, dynamic>? ?? {});
    _token = data['token']?.toString();
    return data;
  }

  Future<Map<String, dynamic>> register(String username, String email, String password, String firstname) async {
    final r = await http.post(Uri.parse('$_base/register'),
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: json.encode({'username': username, 'email': email, 'password': password, 'firstname': firstname}));
    final b = _parse(r);
    final data = (b['data'] as Map<String, dynamic>? ?? {});
    _token = data['token']?.toString();
    return data;
  }

  Future<User> me() async {
    final r = await http.get(Uri.parse('$_base/me'), headers: _headers);
    final b = _parse(r);
    final data = (b['data'] as Map<String, dynamic>? ?? {});
    final user = (data['user'] as Map<String, dynamic>? ?? {});
    return User.fromJson(user);
  }

  Future<void> logout() async {
    try { await http.post(Uri.parse('$_base/logout'), headers: _headers); } catch (_) {}
    _token = null;
  }

  Future<void> subscribe(int channelId) async {
    final r = await http.post(Uri.parse('$_base/subscribe'),
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: json.encode({'channel_id': channelId}));
    _parse(r);
  }

  Future<String?> react(int videoId, String reaction) async {
    final r = await http.post(Uri.parse('$_base/reaction'),
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: json.encode({'video_id': videoId, 'reaction': reaction}));
    final b = _parse(r);
    final data = (b['data'] as Map<String, dynamic>? ?? {});
    return data['reaction']?.toString();
  }

  Future<void> comment(int videoId, String text) async {
    final r = await http.post(Uri.parse('$_base/comment'),
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: json.encode({'video_id': videoId, 'comment': text}));
    _parse(r);
  }
}
