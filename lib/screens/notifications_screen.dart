import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:layn_app/models/models.dart';
import 'package:layn_app/services/api_service.dart';

/// Экран уведомлений/новостей в стиле Telegram-канала.
/// Лента постов из админки (push-рассылки) + плашка Mute/Unmute внизу.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const _mutedKey = 'notifications_muted';

  List<AppNotification> _items = [];
  bool _loading = true;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    _loadMuted();
    _fetch();
  }

  Future<void> _loadMuted() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _muted = prefs.getBool(_mutedKey) ?? false);
  }

  Future<void> _toggleMuted(bool value) async {
    setState(() => _muted = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_mutedKey, value);
    // Лёгкая обратная связь (локальное переключение; при подключении FCM
    // здесь будет отправка статуса подписки на бэкенд).
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? 'Уведомления отключены' : 'Уведомления включены'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final list = await ApiService.instance.notifications();
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
    });
  }

  String _formatDate(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'только что';
      if (diff.inHours < 1) return '${diff.inMinutes} мин. назад';
      if (diff.inDays < 1) return '${diff.inHours} ч. назад';
      if (diff.inDays < 7) return '${diff.inDays} дн. назад';
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Цвета баблов в стиле Telegram
    final bubbleColor = isDark ? const Color(0xFF1C2733) : const Color(0xFFEFFDEF);
    final screenBg = isDark ? const Color(0xFF0F0F0F) : Colors.white;

    return Scaffold(
      backgroundColor: screenBg,
      appBar: AppBar(
        backgroundColor: screenBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Уведомления'),
        actions: [
          IconButton(
            icon: Icon(
              _muted ? Icons.notifications_off_outlined : Icons.notifications_active_outlined,
              color: _muted ? Colors.grey : theme.colorScheme.primary,
            ),
            onPressed: () => _toggleMuted(!_muted),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? _buildEmpty(isDark)
                    : RefreshIndicator(
                        onRefresh: _fetch,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                          itemCount: _items.length,
                          itemBuilder: (context, i) => _buildBubble(_items[i], bubbleColor, isDark),
                        ),
                      ),
          ),
          // Закреплённая плашка управления уведомлениями
          _buildMuteBar(isDark),
        ],
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_none,
            size: 56,
            color: isDark ? Colors.white24 : Colors.black26,
          ),
          const SizedBox(height: 12),
          Text(
            'Пока нет уведомлений',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white38 : Colors.black45,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Новости канала появятся здесь',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          ),
        ],
      ),
    );
  }

  /// Бабл поста — как в Telegram-канале
  Widget _buildBubble(AppNotification n, Color bubbleColor, bool isDark) {
    final hasImage = n.image.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.82,
          ),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(14),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasImage) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    n.image,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (n.subject.isNotEmpty) ...[
                Text(
                  n.subject,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              if (n.message.isNotEmpty)
                Text(
                  n.message,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                _formatDate(n.createdAt),
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Нижняя плашка «Включить / Отключить уведомления»
  Widget _buildMuteBar(bool isDark) {
    final barColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
      decoration: BoxDecoration(
        color: barColor,
        border: Border(
          top: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _toggleMuted(!_muted),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 13),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: _muted
                  ? (isDark ? Colors.white10 : Colors.black12)
                  : (isDark ? const Color(0xFF2A4B7C) : const Color(0xFF065FD4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _muted ? Icons.notifications_off : Icons.notifications_active,
                  size: 19,
                  color: _muted
                      ? (isDark ? Colors.white54 : Colors.black54)
                      : Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  _muted ? 'Включить уведомления' : 'Отключить уведомления',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _muted
                        ? (isDark ? Colors.white54 : Colors.black54)
                        : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
