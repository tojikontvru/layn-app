import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/video_card.dart';
import 'video_screen.dart';
import 'login_screen.dart';
import 'edit_profile_screen.dart';
import 'about_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    return auth.isAuth ? _buildLoggedin(auth) : _buildGuest();
  }

  // === GUEST VIEW ===
  Widget _buildGuest() {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        SizedBox(height: MediaQuery.of(context).padding.top + 40),
        // Header
        Center(
          child: Column(
            children: [
              Icon(Icons.person_outline,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              const Text(
                'Войдите в аккаунт',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Смотрите видео, ставьте лайки\nи подписывайтесь на каналы',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).textTheme.bodySmall?.color),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const LoginScreen())),
                icon: const Icon(Icons.login),
                label: const Text('Войти'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(200, 48),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 48),
        // Theme toggle
        _menuSection([
          SwitchListTile(
            secondary: Icon(
                theme.isDark ? Icons.dark_mode : Icons.light_mode),
            title: const Text('Тёмная тема'),
            value: theme.isDark,
            onChanged: (_) => theme.toggleTheme(),
          ),
        ]),
        _menuSection([
          _menuItem(Icons.info_outline, 'О приложении', () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AboutScreen()));
          }),
        ]),
        const SizedBox(height: 80),
      ],
    );
  }

  // === LOGGED IN VIEW ===
  Widget _buildLoggedin(AuthProvider auth) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // Header with avatar, name
        Container(
          padding: EdgeInsets.fromLTRB(
              16, MediaQuery.of(context).padding.top + 20, 16, 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context)
                    .colorScheme
                    .primary
                    .withOpacity(0.1),
                Theme.of(context).scaffoldBackgroundColor,
              ],
            ),
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundImage: auth.user?.avatar != null &&
                        auth.user!.avatar!.isNotEmpty
                    ? NetworkImage(abs(auth.user!.avatar!))
                    : null,
                child: auth.user?.avatar == null ||
                        auth.user!.avatar!.isEmpty
                    ? Text(
                        (auth.user?.username ?? '?')
                            .substring(0, 1)
                            .toUpperCase(),
                        style: const TextStyle(fontSize: 28),
                      )
                    : null,
              ),
              const SizedBox(height: 12),
              Text(
                auth.user?.channelName ??
                    auth.user?.username ??
                    '',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '@${auth.user?.username ?? ''}',
                style: TextStyle(
                  fontSize: 14,
                  color:
                      Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
        ),

        // Menu items
        _menuSection([
          _menuItem(Icons.edit_outlined, 'Редактировать профиль',
              () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const EditProfileScreen()));
          }),
          _menuItem(Icons.subscriptions_outlined, 'Подписки', () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const _SubscriptionsPage()));
          }),
          _menuItem(Icons.history, 'История просмотров', () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const _HistoryPage()));
          }),
          _menuItem(Icons.thumb_up_outlined, 'Понравившиеся', () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const _LikedPage()));
          }),
        ]),

        // Settings
        _menuSection([
          SwitchListTile(
            secondary: Icon(
                theme.isDark ? Icons.dark_mode : Icons.light_mode),
            title: const Text('Тёмная тема'),
            value: theme.isDark,
            onChanged: (_) => theme.toggleTheme(),
          ),
          _menuItem(Icons.info_outline, 'О приложении', () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AboutScreen()));
          }),
        ]),

        // Logout
        Padding(
          padding: const EdgeInsets.all(16),
          child: OutlinedButton.icon(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Выход'),
                  content:
                      const Text('Выйти из аккаунта?'),
                  actions: [
                    TextButton(
                        onPressed: () =>
                            Navigator.pop(ctx, false),
                        child: const Text('Отмена')),
                    TextButton(
                      onPressed: () =>
                          Navigator.pop(ctx, true),
                      child: const Text('Выйти',
                          style:
                              TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await context.read<AuthProvider>().logout();
              }
            },
            icon: const Icon(Icons.logout, color: Colors.red),
            label: const Text('Выйти из аккаунта',
                style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              side: const BorderSide(color: Colors.red),
            ),
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _menuSection(List<Widget> items) {
    return Container(
      margin: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: items),
    );
  }

  Widget _menuItem(
      IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon,
                size: 22,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
                child: Text(label,
                    style: const TextStyle(fontSize: 15))),
            Icon(Icons.chevron_right,
                size: 20,
                color: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.color),
          ],
        ),
      ),
    );
  }
}

// === SUBSCRIPTIONS PAGE ===
class _SubscriptionsPage extends StatefulWidget {
  const _SubscriptionsPage();

  @override
  State<_SubscriptionsPage> createState() =>
      _SubscriptionsPageState();
}

class _SubscriptionsPageState
    extends State<_SubscriptionsPage> {
  List<VideoUser> _subs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api =
          Provider.of<ApiService>(context, listen: false);
      _subs = await api.subscriptions();
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Не удалось загрузить подписки';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Подписки')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48,
                          color: Theme.of(context)
                              .colorScheme
                              .primary),
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.color)),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _load,
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                )
              : _subs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.subscriptions_outlined,
                              size: 64,
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary),
                          const SizedBox(height: 12),
                          const Text(
                              'Вы пока ни на кого\nне подписались',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8),
                        itemCount: _subs.length,
                        itemBuilder: (ctx, i) {
                          final s = _subs[i];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: s.avatar !=
                                          null &&
                                      s.avatar!.isNotEmpty
                                  ? NetworkImage(
                                      abs(s.avatar!))
                                  : null,
                              child: s.avatar == null ||
                                      s.avatar!.isEmpty
                                  ? Text((s.channelName ??
                                          s.username ??
                                          '?')[0]
                                      .toUpperCase())
                                  : null,
                            ),
                            title: Text(s.channelName ??
                                s.username ??
                                ''),
                            subtitle: Text(
                                '@${s.username ?? ''}'),
                          );
                        },
                      ),
                    ),
    );
  }
}

// === HISTORY PAGE ===
class _HistoryPage extends StatefulWidget {
  const _HistoryPage();

  @override
  State<_HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<_HistoryPage> {
  List<Video> _videos = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      _videos = await api.history();
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Раздел временно недоступен';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('История просмотров'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history,
                          size: 48,
                          color: Theme.of(context)
                              .colorScheme
                              .primary),
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.color)),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _load,
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                )
              : _videos.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history,
                              size: 64,
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary),
                          const SizedBox(height: 12),
                          const Text(
                              'История просмотров пуста',
                              style: TextStyle(
                                  fontSize: 16)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        itemCount: _videos.length,
                        itemBuilder: (ctx, i) => VideoCard(
                          video: _videos[i],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => VideoScreen(
                                  video: _videos[i]),
                            ),
                          ),
                        ),
                      ),
                    ),
    );
  }
}

// === LIKED PAGE ===
class _LikedPage extends StatefulWidget {
  const _LikedPage();

  @override
  State<_LikedPage> createState() => _LikedPageState();
}

class _LikedPageState extends State<_LikedPage> {
  List<Video> _videos = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      _videos = await api.likedVideos();
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Раздел временно недоступен';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Понравившиеся')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.thumb_up_outlined,
                          size: 48,
                          color: Theme.of(context)
                              .colorScheme
                              .primary),
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.color)),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _load,
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                )
              : _videos.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.thumb_up_outlined,
                              size: 64,
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary),
                          const SizedBox(height: 12),
                          const Text(
                              'Нет понравившихся видео',
                              style: TextStyle(
                                  fontSize: 16)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        itemCount: _videos.length,
                        itemBuilder: (ctx, i) => VideoCard(
                          video: _videos[i],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => VideoScreen(
                                  video: _videos[i]),
                            ),
                          ),
                        ),
                      ),
                    ),
    );
  }
}
