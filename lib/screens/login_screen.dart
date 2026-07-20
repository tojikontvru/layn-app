import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'register_screen.dart';

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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Вход', style: TextStyle(color: Colors.white)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.person, color: Colors.white24, size: 80),
          const SizedBox(height: 40),
          TextField(
            controller: _u,
            style: const TextStyle(color: Colors.white),
            decoration: _deco('Логин', Icons.person_outline),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _p,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: _deco('Пароль', Icons.lock_outline),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
          ],
          const SizedBox(height: 24),
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: _loading ? null : _login,
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6C5CE7)),
              child: _loading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Войти', style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RegisterScreen()));
            },
            child: const Text('Нет аккаунта? Зарегистрироваться',
                style: TextStyle(color: Color(0xFF6C5CE7))),
          ),
        ],
      ),
    );
  }

  InputDecoration _deco(String label, IconData icon) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.grey),
    prefixIcon: Icon(icon, color: Colors.grey),
    filled: true,
    fillColor: const Color(0xFF1A1A1A),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF6C5CE7))),
  );

  @override
  void dispose() {
    _u.dispose();
    _p.dispose();
    super.dispose();
  }
}
