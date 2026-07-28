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
    _focus.unfocus();
    setState(() { _loading = true; _searched = true; });
    try {
      final list = await ApiService.instance.search(q);
      setState(() { _results = list; _loading = false; });
    } catch (_) {
      setState(() { _results = []; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(children: [
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _ctrl,
            focusNode: _focus,
            style: theme.textTheme.bodyLarge,
            decoration: InputDecoration(
              hintText: 'Поиск видео...',
              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.grey[600] : Colors.grey[500],
              ),
              prefixIcon: Icon(Icons.search,
                  color: isDark ? Colors.grey : Colors.grey[600]),
              filled: true,
              fillColor: isDark
                  ? const Color(0xFF1A1A1A)
                  : const Color(0xFFF5F5F5),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              suffixIcon: _ctrl.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear,
                          color: isDark ? Colors.grey : Colors.grey[600]),
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
            ? Center(
                child: CircularProgressIndicator(
                    color: theme.colorScheme.primary))
            : !_searched
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.search,
                          color: isDark ? Colors.grey[800] : Colors.grey[400],
                          size: 64),
                      const SizedBox(height: 12),
                      Text('Найти видео',
                          style: TextStyle(
                              color: isDark ? Colors.grey[600] : Colors.grey[500],
                              fontSize: 16)),
                    ]),
                  )
                : _results.isEmpty
                    ? Center(
                        child: Text('Ничего не найдено',
                            style: TextStyle(
                                color: isDark ? Colors.grey : Colors.grey[600])))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: _results.length,
                        itemBuilder: (_, i) => VideoCard(
                          video: _results[i],
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) =>
                                  VideoScreen(video: _results[i], related: _results))),
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
