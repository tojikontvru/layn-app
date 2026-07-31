import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_service.dart';

/// Сервис проверки обновлений приложения.
///
/// Логика (по новому бэкенду):
/// 1. GET /api/v1/app-settings → data: { enabled, force_update, show_update_notice,
///    app_version, download_url, update_title, update_message, changelog }
/// 2. Если `enabled != true` — ничего не показываем (админ выключил).
/// 3. Сравниваем app_version с текущей версией приложения.
/// 4. Если версия новее:
///    - force_update=true → экран без возможности закрыть («Обновить сейчас»)
///    - show_update_notice=true → диалог с changelog + кнопки «Позже» / «Обновить»
class UpdateService {
  static Future<void> checkForUpdates(BuildContext context) async {
    try {
      final api = ApiService.instance;
      final response = await api.getSettings();
      if (response == null) return;

      final data = response['data'] as Map<String, dynamic>?;
      if (data == null) return;

      // Главный тумблер: обновления выключены админом — молчим
      final enabled = data['enabled'] == true;
      if (!enabled) return;

      final appVersion = data['app_version'] as String? ?? '';
      final downloadUrl = data['download_url'] as String? ?? '';
      final updateTitle = data['update_title'] as String? ?? 'Доступно обновление';
      final updateMessage = data['update_message'] as String? ?? 'Вышла новая версия приложения. Обновитесь, чтобы получить новые функции.';
      final changelog = data['changelog'] as String? ?? '';

      final currentVersion = await _getCurrentVersion();
      final hasNewVersion = _isNewer(appVersion, currentVersion);
      if (!hasNewVersion || downloadUrl.isEmpty) return;

      final forceUpdate = data['force_update'] == true;
      final showNotice = data['show_update_notice'] == true;

      if (!context.mounted) return;

      if (forceUpdate) {
        _showForceUpdateScreen(context, downloadUrl, updateTitle, updateMessage, changelog);
      } else if (showNotice) {
        _showUpdateNoticeDialog(context, downloadUrl, updateTitle, updateMessage, changelog);
      }
    } catch (e) {
      debugPrint('UpdateService: check failed: $e');
    }
  }

  // ─── Принудительное обновление (нельзя закрыть) ─────────────
  static void _showForceUpdateScreen(
      BuildContext context, String url, String title, String message, String changelog) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: _UpdateDialog(
          icon: Icons.system_update_alt_rounded,
          iconColor: const Color(0xFFF59E0B),
          title: title,
          message: message,
          changelog: changelog,
          force: true,
          onUpdate: () => _launch(url, ctx),
        ),
      ),
    );
  }

  // ─── Обычное уведомление (можно пропустить) ─────────────────
  static void _showUpdateNoticeDialog(
      BuildContext context, String url, String title, String message, String changelog) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: true,
        child: _UpdateDialog(
          icon: Icons.new_releases_rounded,
          iconColor: const Color(0xFF3EA6FF),
          title: title,
          message: message,
          changelog: changelog,
          force: false,
          onUpdate: () => _launch(url, ctx),
        ),
      ),
    );
  }

  static Future<void> _launch(String url, BuildContext ctx) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('UpdateService: launch failed: $e');
    }
    if (ctx.mounted) Navigator.of(ctx).pop();
  }

  static Future<String> _getCurrentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (_) {}
    return '1.0.0';
  }

  static bool _isNewer(String remote, String current) {
    try {
      final rParts = remote.split('.').map(int.parse).toList();
      final cParts = current.split('.').map(int.parse).toList();
      for (int i = 0; i < 3; i++) {
        final r = rParts.length > i ? rParts[i] : 0;
        final c = cParts.length > i ? cParts[i] : 0;
        if (r > c) return true;
        if (r < c) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}

/// Диалог обновления в стиле приложения: тёмная карточка, blur,
/// changelog списком, акцентные кнопки.
class _UpdateDialog extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String changelog;
  final bool force;
  final VoidCallback onUpdate;

  const _UpdateDialog({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.changelog,
    required this.force,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1C1814) : Colors.white;
    final textColor = isDark ? const Color(0xFFE6D3BA) : Colors.black87;
    final subColor = isDark ? const Color(0xFF8A7C6C) : Colors.grey.shade600;
    final borderColor = isDark ? const Color(0xFF3A3228) : Colors.grey.shade200;

    final changelogItems = changelog
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Иконка в круге
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: iconColor),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, height: 1.45, color: subColor),
            ),
            if (changelogItems.isNotEmpty) ...[
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F0F0F)
                      : const Color(0xFFF6F4F0),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Что нового',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final item in changelogItems) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: iconColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              item,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: subColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (item != changelogItems.last) const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 22),
            // Кнопки
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: onUpdate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF065FD4),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.download_rounded, size: 20),
                    SizedBox(width: 8),
                    Text('Обновить'),
                  ],
                ),
              ),
            ),
            if (!force) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: subColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Позже', style: TextStyle(fontSize: 14)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
