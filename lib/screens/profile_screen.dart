import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.isAuth) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.person_outline, color: Colors.white24, size: 80),
          const SizedBox(height: 16),
          const Text('Войдите в аккаунт', style: TextStyle(color: Colors.white54, fontSize: 18)),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const LoginScreen())),
            icon: const Icon(Icons.login),
            label: const Text('Вход / Регистрация'),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6C5CE7)),
          ),
        ]),
      );
    }

    final user = auth.user!;
    return ListView(padding: const EdgeInsets.all(20), children: [
      Center(
        child: CircleAvatar(
          radius: 40,
          backgroundColor: const Color(0xFF333),
          backgroundImage: (user.avatar ?? '').isNotEmpty ? NetworkImage(user.avatar!) : null,
          child: (user.avatar == null || user.avatar!.isEmpty)
              ? Text((user.username ?? '?')[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 28))
              : null,
        ),
      ),
      const SizedBox(height: 16),
      Center(
        child: Text(user.channelName ?? user.username ?? '',
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      ),
      const SizedBox(height: 32),
      ListTile(
        leading: const Icon(Icons.logout, color: Colors.red),
        title: const Text('Выйти', style: TextStyle(color: Colors.white)),
        onTap: () => auth.logout(),
      ),
    ]);
  }
}
