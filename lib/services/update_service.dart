import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_service.dart';

class UpdateService {
  static Future<void> checkForUpdates(BuildContext context) async {
    try {
      final api = ApiService.instance;
      final response = await api.getSettings();

      if (response == null) return;

      final data = response['data'] as Map<String, dynamic>?;
      if (data == null) return;

      final forceUpdate = data['force_update'] == true;
      final showNotice = data['show_update_notice'] == true;
      final appVersion = data['app_version'] as String? ?? '1.0.0';
      final downloadUrl = data['download_url'] as String? ?? '';
      final updateTitle = data['update_title'] as String? ?? 'New Update Available';
      final updateMessage = data['update_message'] as String? ?? 'A new version is available. Please update to continue.';

      final currentVersion = await _getCurrentVersion();
      final hasNewVersion = _isNewer(appVersion, currentVersion);

      if (!hasNewVersion) return;

      if (forceUpdate) {
        _showForceUpdateDialog(context, downloadUrl, updateTitle, updateMessage);
      } else if (showNotice) {
        _showUpdateNoticeDialog(context, downloadUrl, updateTitle, updateMessage);
      }
    } catch (e) {
      debugPrint('UpdateService: check failed: $e');
    }
  }

  static void _showForceUpdateDialog(
      BuildContext context, String url, String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            ElevatedButton(
              onPressed: () {
                if (url.isNotEmpty) {
                  launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                }
              },
              child: const Text('Update Now'),
            ),
          ],
        ),
      ),
    );
  }

  static void _showUpdateNoticeDialog(
      BuildContext context, String url, String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              if (url.isNotEmpty) {
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
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
