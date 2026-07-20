import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('Профиль', style: TextStyle(color: Colors.white)),
      ),
      body: auth.isAuth ? _buildProfile(context, auth) : _buildGuest(context),
    );
  }

  Widget _buildProfile(BuildContext context, AuthProvider auth) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 20),
        // Avatar
        Center(
          child: CircleAvatar(
            radius: 48,
            backgroundColor: const Color(0xFF333),
            backgroundImage: (auth.user?.avatar ?? '').isNotEmpty
                ? NetworkImage(auth.user!.avatar!)
                : null,
            child: (auth.user?.avatar == null || auth.user!.avatar!.isEmpty)
                ? Text(
                    (auth.user?.username ?? 'U')[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 16),
        // Username
        Center(
          child: Text(
            auth.user?.username ?? '',
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 4),
        // Channel name
        if (auth.user?.channelName != null)
          Center(
            child: Text(
              auth.user!.channelName!,
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
          ),
        const SizedBox(height: 32),

        // Settings
        _menuItem(Icons.edit, 'Редактировать профиль', () {}),
        _menuItem(Icons.subscriptions_outlined, 'Подписки', () {}),
        _menuItem(Icons.history, 'История просмотров', () {}),
        _menuItem(Icons.download, 'Загрузки', () {}),
        _menuItem(Icons.dark_mode_outlined, 'Тёмная тема', () {}, trailing: Switch(
          value: true,
          onChanged: (_) {},
          activeColor: const Color(0xFF6C5CE7),
        )),
        _menuItem(Icons.info_outline, 'О приложении', () {}),

        const SizedBox(height: 24),
        // Logout
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () async {
              await auth.logout();
              if (context.mounted) Navigator.of(context).popUntil((route) => route.isFirst);
            },
            icon: const Icon(Icons.logout, color: Colors.red),
            label: const Text('Выйти', style: TextStyle(color: Colors.red, fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _buildGuest(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.person_outline, color: Colors.white24, size: 80),
        const SizedBox(height: 24),
        const Text('Войдите в аккаунт', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('Чтобы подписываться и комментировать', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
        const SizedBox(height: 32),
        SizedBox(
          width: 200,
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6C5CE7), padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
            child: const Text('Войти', style: TextStyle(fontSize: 16)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 200,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF6C5CE7)), padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
            child: const Text('Регистрация', style: TextStyle(color: Color(0xFF6C5CE7), fontSize: 16)),
          ),
        ),
      ]),
    );
  }

  Widget _menuItem(IconData icon, String label, VoidCallback onTap, {Widget? trailing}) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      trailing: trailing ?? const Icon(Icons.chevron_right, color: Colors.white30),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}
