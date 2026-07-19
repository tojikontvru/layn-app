import 'package:cached_network_image/cached_network_image.dart';
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
      return Container(
        color: const Color(0xFF0F0F0F),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('Войдите в аккаунт', style: TextStyle(color: Colors.grey, fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
                child: const Text('Войти', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    final user = auth.user!;
    return Container(
      color: const Color(0xFF0F0F0F),
      child: Column(
        children: [
          Container(
            color: const Color(0xFF1A1A1A),
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 8, left: 16, right: 16, bottom: 16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFF333333),
                  backgroundImage: (user.avatar ?? '').isNotEmpty ? NetworkImage(user.avatar!) : null,
                  child: (user.avatar == null || user.avatar!.isEmpty)
                      ? Text(user.username[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 20))
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.channelName ?? user.username, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 2),
                      Text('@${user.username}', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _menuItem(Icons.subscriptions, 'Подписки'),
                _menuItem(Icons.video_library, 'Мои видео'),
                _menuItem(Icons.monetization_on, 'Монетизация'),
                _menuItem(Icons.settings, 'Настройки'),
                _menuItem(Icons.info_outline, 'О приложении'),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.redAccent),
                  title: const Text('Выйти', style: TextStyle(color: Colors.redAccent)),
                  onTap: () => auth.logout(),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuItem(IconData icon, String title) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}
