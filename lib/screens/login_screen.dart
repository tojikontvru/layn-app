import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _u = TextEditingController();
  final _p = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    setState(() { _loading = true; _error = null; });
    try {
      await context.read<AuthProvider>().login(_u.text.trim(), _p.text);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() { _error = 'Неверный логин или пароль'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Вход'), backgroundColor: const Color(0xFF0E0E0E)),
      backgroundColor: const Color(0xFF0E0E0E),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.person, color: Colors.white24, size: 80),
          const SizedBox(height: 40),
          TextField(
            controller: _u,
            style: const TextStyle(color: Colors.white),
            decoration: _deco('Логин'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _p,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: _deco('Пароль'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _loading ? null : _login,
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6C5CE7)),
            child: _loading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Войти'),
          ),
        ],
      ),
    );
  }

  InputDecoration _deco(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      );

  @override
  void dispose() {
    _u.dispose();
    _p.dispose();
    super.dispose();
  }
}
