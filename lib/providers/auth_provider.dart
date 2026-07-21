import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService api;
  VideoUser? _user;
  bool _loading = false;
  String? _email;
  String? _firstName;
  String? _lastName;
  String? _description;

  AuthProvider(this.api);

  VideoUser? get user => _user;
  bool get isAuth => _user != null;
  bool get loggedIn => _user != null;
  bool get loading => _loading;
  int? get userId => _user?.id;
  String? get email => _email;
  String? get firstName => _firstName;
  String? get lastName => _lastName;
  String? get description => _description;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token != null && token.isNotEmpty) {
        api.setToken(token);
        await _fetchUser();
      }
    } catch (_) {
      api.setToken(null);
    }
  }

  Future<void> _fetchUser() async {
    try {
      final d = await api.me();
      final u = d['data'] ?? d;
      if (u != null && u is Map) {
        _user = VideoUser(
          id: u['id'],
          username: u['username'],
          channelName: u['channel_name'] ?? u['firstname'],
          avatar: abs(u['avatar'] ?? u['image'] ?? ''),
        );
        _email = u['email'];
        _firstName = u['firstname'];
        _lastName = u['lastname'];
        _description = u['description'];
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> login(String username, String password) async {
    _loading = true;
    notifyListeners();
    try {
      final d = await api.login(username, password);
      _saveSession(d);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> register(String username, String email, String password) async {
    _loading = true;
    notifyListeners();
    try {
      final d = await api.register(username, email, password);
      _saveSession(d);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void _saveSession(Map<String, dynamic> d) async {
    final data = d['data'] ?? d;
    final token = data['token'];
    if (token != null) {
      api.setToken(token);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
    }
    final u = data['user'] ?? data;
    if (u != null && u is Map) {
      _user = VideoUser(
        id: u['id'],
        username: u['username'],
        channelName: u['channel_name'] ?? u['firstname'],
        avatar: abs(u['avatar'] ?? u['image'] ?? ''),
      );
      _email = u['email'];
      _firstName = u['firstname'];
      _lastName = u['lastname'];
      _description = u['description'];
      notifyListeners();
    }
  }

  Future<void> updateProfile({
    String? username,
    String? email,
    String? firstname,
    String? lastname,
    String? channelName,
    String? description,
  }) async {
    await api.updateProfile(
      username: username,
      email: email,
      firstname: firstname,
      lastname: lastname,
      channelName: channelName,
      description: description,
    );
    await _fetchUser();
  }

  Future<void> logout() async {
    await api.logout();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    _user = null;
    _email = null;
    _firstName = null;
    _lastName = null;
    _description = null;
    notifyListeners();
  }
}
