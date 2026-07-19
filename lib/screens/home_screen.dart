import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/update_service.dart';
import '../models/models.dart';
import '../widgets/video_card.dart';
import 'video_screen.dart';
import 'shorts_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedTab = 0;

  void _goHome() {
    if (_selectedTab != 0) setState(() => _selectedTab = 0);
  }

  Widget _buildBody() {
    switch (_selectedTab) {
      case 0: return const _HomeBody();
      case 1: return ShortsScreen(onBack: _goHome);
      case 2: return const _SearchPage();
      case 3: return const ProfileScreen();
      default: return const _HomeBody();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedTab == 0,
      onPopInvokedWithResult: (didPop, result) { if (!didPop) _goHome(); },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        body: _buildBody(),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(color: Color(0xFF1A1A1A), border: Border(top: BorderSide(color: Color(0xFF2A2A2A), width: 0.5))),
          child: BottomNavigationBar(
            backgroundColor: const Color(0xFF1A1A1A),
            selectedItemColor: const Color(0xFFE53935),
            unselectedItemColor: Colors.grey,
            type: BottomNavigationBarType.fixed,
            currentIndex: _selectedTab,
            selectedFontSize: 10,
            unselectedFontSize: 10,
            onTap: (i) => setState(() => _selectedTab = i),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Главная'),
              BottomNavigationBarItem(icon: Icon(Icons.short_text), activeIcon: Icon(Icons.short_text), label: 'Shorts'),
              BottomNavigationBarItem(icon: Icon(Icons.search), activeIcon: Icon(Icons.search), label: 'Поиск'),
              BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Профиль'),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeBody extends StatefulWidget {
  const _HomeBody();
  @override
  State<_HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<_HomeBody> {
  final List<Video> _videos = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _currentPage = 1;
  int _lastPage = 1;
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 300) _loadMore();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = context.read<ApiService>();
      final data = await api.home(page: 1);
      final list = (data['videos'] as List? ?? []).map((e) => Video.fromJson(e as Map<String, dynamic>)).where((v) => !v.isShorts).toList();
      if (mounted) {
        setState(() {
          _videos..clear()..addAll(list);
          _currentPage = data['current_page'] ?? 1;
          _lastPage = data['last_page'] ?? 1;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _currentPage >= _lastPage) return;
    setState(() => _loadingMore = true);
    try {
      final api = context.read<ApiService>();
      final data = await api.home(page: _currentPage + 1);
      final list = (data['videos'] as List? ?? []).map((e) => Video.fromJson(e as Map<String, dynamic>)).where((v) => !v.isShorts).toList();
      if (mounted) {
        setState(() {
          _videos.addAll(list);
          _currentPage = data['current_page'] ?? _currentPage + 1;
          _lastPage = data['last_page'] ?? _lastPage;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: const Color(0xFF1A1A1A),
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top, left: 12, right: 12, bottom: 8),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: const Color(0xFFE53935), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 20)),
            const SizedBox(width: 8),
            const Text('Layn', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.system_update_alt, color: Colors.white), tooltip: 'Проверка обновлений',
              onPressed: () => UpdateService.checkForUpdates(context, showAlways: true)),
            IconButton(icon: const Icon(Icons.notifications_none, color: Colors.white), onPressed: () {}),
          ]),
        ),
        Expanded(
          child: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)))
            : _error != null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                  const SizedBox(height: 12),
                  Text('Ошибка загрузки', style: TextStyle(color: Colors.grey[400], fontSize: 16)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Повторить'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935))),
                ]))
              : _videos.isEmpty
                ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.video_library_outlined, size: 64, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('Нет видео', style: TextStyle(color: Colors.grey, fontSize: 16)),
                  ]))
                : RefreshIndicator(
                    color: const Color(0xFFE53935),
                    onRefresh: _load,
                    child: ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.only(top: 8, bottom: 16),
                      itemCount: _videos.length + (_currentPage < _lastPage ? 1 : 0),
                      itemBuilder: (c, i) {
                        if (i >= _videos.length) {
                          return const Padding(padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator(color: Color(0xFFE53935))));
                        }
                        return VideoCard(video: _videos[i], onTap: () =>
                          Navigator.push(context, MaterialPageRoute(builder: (_) => VideoScreen(video: _videos[i]))));
                      },
                    ),
                  ),
        ),
      ],
    );
  }
}

class _SearchPage extends StatefulWidget {
  const _SearchPage();
  @override
  State<_SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<_SearchPage> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  List<dynamic> _results = [];
  bool _loading = false;
  bool _searched = false;
  String? _error;

  @override
  void initState() { super.initState(); _focus.requestFocus(); }

  Future<void> _search() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    setState(() { _loading = true; _searched = true; _error = null; });
    try { final results = await context.read<ApiService>().search(q); if (mounted) setState(() => _results = results); }
    catch (e) { if (mounted) setState(() => _error = e.toString()); }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: TextField(controller: _ctrl, focusNode: _focus, style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(hintText: 'Поиск видео...', hintStyle: TextStyle(color: Colors.grey[500]), border: InputBorder.none),
          onSubmitted: (_) => _search()),
        actions: [IconButton(onPressed: _search, icon: const Icon(Icons.search, color: Color(0xFFE53935)))],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)))
        : !_searched
          ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.search, size: 64, color: Colors.grey),
              SizedBox(height: 12),
              Text('Найдите любимые видео', style: TextStyle(color: Colors.grey, fontSize: 16)),
            ]))
          : _error != null
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                const SizedBox(height: 12),
                Text('Ошибка поиска', style: TextStyle(color: Colors.grey[400])),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _search, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
                  child: const Text('Повторить')),
              ]))
            : _results.isEmpty
              ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.search_off, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('Ничего не найдено', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: _results.length,
                  itemBuilder: (c, i) => VideoCard(video: _results[i],
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VideoScreen(video: _results[i])))),
                ),
    );
  }
}