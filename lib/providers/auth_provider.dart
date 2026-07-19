import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService api;
  User? _user;
  bool _loading = false;
  bool _initialized = false;

  AuthProvider({required this.api});

  User? get user => _user;
  bool get isAuth => _user != null;
  bool get loading => _loading;
  bool get initialized => _initialized;

  Future<void> init() async {
    _initialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token != null && token.isNotEmpty) {
        api.setToken(token);
        _user = await api.me();
        notifyListeners();
      }
    } catch (e) {
      api.setToken(null);
    }
  }

  Future<void> login(String username, String password) async {
    _loading = true;
    notifyListeners();
    try {
      final data = await api.login(username, password);
      final token = data['token']?.toString();
      if (token != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token);
        api.setToken(token);
        _user = await api.me();
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> register(String username, String email, String password, String firstname) async {
    _loading = true;
    notifyListeners();
    try {
      final data = await api.register(username, email, password, firstname);
      final token = data['token']?.toString();
      if (token != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token);
        api.setToken(token);
        _user = await api.me();
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await api.logout();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    _user = null;
    notifyListeners();
  }
}
