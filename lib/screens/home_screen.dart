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
  bool _loading = true;
  String? _error;
  int _page = 1;
  bool _more = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final d = await ApiService.instance.home(page: _page);
      final list = (d['data']?['videos'] as List? ?? [])
          .map((e) => Video.fromJson(e as Map<String, dynamic>))
          .where((v) => !v.isShorts)
          .toList();
      setState(() {
        _videos.clear();
        _videos.addAll(list);
        _more = list.length >= 10;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF6C5CE7)));
    }
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, color: Colors.red, size: 48),
        const SizedBox(height: 12),
        Text(_error!, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 16),
        FilledButton(onPressed: _load, child: const Text('Повторить')),
      ]));
    }
    if (_videos.isEmpty) {
      return const Center(child: Text('Нет видео', style: TextStyle(color: Colors.white54)));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _videos.length,
        itemBuilder: (_, i) => VideoCard(
          video: _videos[i],
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => VideoScreen(video: _videos[i]))),
        ),
      ),
    );
  }
}
