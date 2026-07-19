import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  static const String _versionUrl = 'https://layn.su/assets/app-version.json';

  static Future<void> checkForUpdates(BuildContext context, {bool showAlways = false}) async {
    try {
      final response = await http.get(Uri.parse(_versionUrl)).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return;

      final data = json.decode(response.body);
      final serverVersion = data['version'] ?? '';
      final serverBuild = data['build'] ?? 0;
      final downloadUrl = data['download_url'] ?? '';
      final changelog = data['changelog'] ?? '';

      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;

      if (serverBuild > currentBuild && context.mounted) {
        _showUpdateDialog(context, version: serverVersion, downloadUrl: downloadUrl, changelog: changelog);
      } else if (showAlways && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('У вас последняя версия'),
          ]),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ));
      }
    } catch (_) {
      if (showAlways && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Не удалось проверить обновления'),
          backgroundColor: Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  static void _showUpdateDialog(BuildContext context, {required String version, required String downloadUrl, required String changelog}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.system_update, color: Color(0xFFE53935)),
          SizedBox(width: 8),
          Text('Обновление', style: TextStyle(color: Colors.white)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Версия $version', style: const TextStyle(color: Color(0xFFE53935))),
            const SizedBox(height: 8),
            if (changelog.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(8)),
                child: Text(changelog, style: TextStyle(color: Colors.grey[300], fontSize: 13)),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Позже', style: TextStyle(color: Colors.grey[400]))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final uri = Uri.parse(downloadUrl);
              if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
            child: const Text('Скачать', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
