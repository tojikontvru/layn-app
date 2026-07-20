import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/video_card.dart';
import 'video_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _videos = <Video>[];
  final _categories = <Category>[];
  final _scrollCtrl = ScrollController();
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  int _lastPage = 1;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _loadAll();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  Future<void> _loadAll() async {
    await _loadCategories();
    await _loadVideos();
  }

  Future<void> _loadCategories() async {
    final cats = await ApiService.instance.categories();
    if (mounted) {
      if (cats.isEmpty) {
        setState(() => _categories.addAll([
          Category(id: 1, name: 'Музыка', slug: 'mus8c'),
          Category(id: 2, name: 'Фильмы', slug: 'movie'),
          Category(id: 3, name: 'Сериалы', slug: 'series'),
          Category(id: 4, name: 'Развлечение', slug: 'entertainment'),
        ]));
      } else {
        setState(() => _categories.addAll(cats));
      }
    }
  }

  Future<void> _loadVideos() async {
    setState(() { _loading = true; _error = null; _page = 1; });
    try {
      final d = await ApiService.instance.home(page: 1, category: _selectedCategory);
      final videosRaw = (d['data']?['videos'] as List? ?? []);
      final list = videosRaw
          .map((e) => Video.fromJson(e as Map<String, dynamic>))
          .toList();
      
      final meta = d['data'] ?? {};
      setState(() {
        _videos.clear();
        _videos.addAll(list);
        _lastPage = meta['last_page'] ?? 1;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _page >= _lastPage) return;
    setState(() => _loadingMore = true);
    try {
      final nextPage = _page + 1;
      final d = await ApiService.instance.home(page: nextPage, category: _selectedCategory);
      final videosRaw = (d['data']?['videos'] as List? ?? []);
      final list = videosRaw
          .map((e) => Video.fromJson(e as Map<String, dynamic>))
          .toList();
      
      if (mounted) {
        setState(() {
          _videos.addAll(list);
          _page = nextPage;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onCategorySelected(String? slug) {
    if (_selectedCategory == slug) return;
    setState(() => _selectedCategory = slug);
    _loadVideos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: false,
        title: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/images/logo.png',
              height: 32,
              width: 32,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 8),
          const Text('Layn',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 26),
            onPressed: () {},
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(children: [
        _buildCategories(),
        Expanded(child: _buildBody()),
      ]),
    );
  }

  Widget _buildCategories() {
    return Container(
      height: 48,
      color: Colors.black,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          _catChip('Все', null),
          ..._categories.map((c) => _catChip(c.name, c.slug)),
        ],
      ),
    );
  }

  Widget _catChip(String label, String? slug) {
    final active = _selectedCategory == slug;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => _onCategorySelected(slug),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: active ? Colors.white : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active ? Colors.white : const Color(0xFF333),
              width: 1,
            ),
          ),
          child: Text(label,
              style: TextStyle(
                color: active ? Colors.black : Colors.grey[400],
                fontSize: 13,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              )),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)));
    }
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, color: Colors.red, size: 48),
        const SizedBox(height: 12),
        Text(_error!, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 16),
        FilledButton(onPressed: _loadVideos, child: const Text('Повторить')),
      ]));
    }
    if (_videos.isEmpty) {
      return const Center(child: Text('Нет видео', style: TextStyle(color: Colors.white54)));
    }
    return RefreshIndicator(
      color: const Color(0xFFE53935),
      onRefresh: _loadVideos,
      child: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.only(top: 4, bottom: 16),
        itemCount: _videos.length + (_loadingMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == _videos.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(color: Color(0xFFE53935))),
            );
          }
          return VideoCard(
            video: _videos[i],
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => VideoScreen(video: _videos[i]))),
          );
        },
      ),
    );
  }
}
