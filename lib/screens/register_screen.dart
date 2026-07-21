import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final auth = context.read<AuthProvider>();
      await auth.register(
        _usernameCtrl.text.trim(),
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      setState(() { _error = msg; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Регистрация', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SizedBox(height: 20),
              const Icon(Icons.person_add_outlined, color: Color(0xFF6C5CE7), size: 64),
              const SizedBox(height: 24),
              const Text('Создайте аккаунт', textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              TextFormField(
                controller: _usernameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Имя пользователя', Icons.person_outline),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите имя пользователя' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Email', Icons.email_outlined),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Введите email';
                  if (!v.contains('@')) return 'Некорректный email';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Имя', Icons.badge_outlined),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Пароль', Icons.lock_outline),
                validator: (v) => (v == null || v.length < 6) ? 'Минимум 6 символов' : null,
              ),
              const SizedBox(height: 24),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(_error!, textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red, fontSize: 13)),
                ),
              SizedBox(
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6C5CE7)),
                  onPressed: _loading ? null : _register,
                  child: _loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Зарегистрироваться', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Уже есть аккаунт? Войти',
                    style: TextStyle(color: Color(0xFF6C5CE7))),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.grey),
    prefixIcon: Icon(icon, color: Colors.grey),
    filled: true,
    fillColor: const Color(0xFF1A1A1A),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF6C5CE7))),
  );
}
