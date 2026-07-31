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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F0F0F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final fieldBg = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF2F2F2);
    final iconColor = isDark ? Colors.white24 : Colors.black38;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        iconTheme: IconThemeData(color: textColor),
        title: Text('Вход', style: TextStyle(color: textColor)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 40),
          Icon(Icons.person, color: iconColor, size: 80),
          const SizedBox(height: 40),
          TextField(
            controller: _u,
            style: TextStyle(color: textColor),
            decoration: _deco('Логин', Icons.person_outline, fieldBg, isDark),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _p,
            obscureText: true,
            style: TextStyle(color: textColor),
            decoration: _deco('Пароль', Icons.lock_outline, fieldBg, isDark),
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
              style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
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
            child: Text('Нет аккаунта? Зарегистрироваться',
                style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          ),
        ],
      ),
    );
  }

  InputDecoration _deco(String label, IconData icon, Color fieldBg, bool isDark) => InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: isDark ? Colors.grey : Colors.grey.shade600),
    prefixIcon: Icon(icon, color: isDark ? Colors.grey : Colors.grey.shade600),
    filled: true,
    fillColor: fieldBg,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
  );

  @override
  void dispose() {
    _u.dispose();
    _p.dispose();
    super.dispose();
  }
}
