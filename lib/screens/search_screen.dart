import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/video_card.dart';
import 'video_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  List<Video> _results = [];
  bool _searched = false;
  bool _loading = false;

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) return;
    setState(() { _loading = true; _searched = true; });
    try {
      final d = await ApiService.instance.search(q);
      final list = (d['data'] as List? ?? [])
          .map((e) => Video.fromJson(e as Map<String, dynamic>))
          .where((v) => !v.isShorts)
          .toList();
      setState(() { _results = list; _loading = false; });
    } catch (_) {
      setState(() { _results = []; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _ctrl,
            focusNode: _focus,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Поиск видео...',
              hintStyle: TextStyle(color: Colors.grey[600]),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: const Color(0xFF1A1A1A),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              suffixIcon: _ctrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () { _ctrl.clear(); setState(() {}); })
                  : null,
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: _search,
            onChanged: (_) => setState(() {}),
          ),
        ),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C5CE7)))
            : !_searched
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.search, color: Colors.grey[800], size: 64),
                      const SizedBox(height: 12),
                      Text('Найти видео', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                    ]),
                  )
                : _results.isEmpty
                    ? const Center(child: Text('Ничего не найдено', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: _results.length,
                        itemBuilder: (_, i) => VideoCard(
                          video: _results[i],
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => VideoScreen(video: _results[i]))),
                        ),
                      ),
      ),
    ]);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }
}
