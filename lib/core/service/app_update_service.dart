import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class AppUpdateService {
  static const String _collection = 'app_versions';
  static const String _docId = 'android';

  static Future<void> checkForUpdate(BuildContext context) async {
    if (!Platform.isAndroid) return;
    try {
      final info = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(info.buildNumber) ?? 0;

      final doc = await FirebaseFirestore.instance
          .collection(_collection)
          .doc(_docId)
          .get();

      if (!doc.exists) return;
      final data = doc.data()!;
      final latestBuild = (data['version_code'] as num?)?.toInt() ?? 0;
      final apkUrl = data['apk_url'] as String?;
      final releaseNotes = data['release_notes'] as String? ?? '';
      final versionName = data['version_name'] as String? ?? '';
      final forceUpdate = data['force_update'] as bool? ?? false;

      if (latestBuild <= currentBuild || apkUrl == null) return;

      if (context.mounted) {
        _showUpdateDialog(
          context,
          apkUrl: apkUrl,
          versionName: versionName,
          releaseNotes: releaseNotes,
          forceUpdate: forceUpdate,
        );
      }
    } catch (_) {
    }
  }

  static void _showUpdateDialog(
    BuildContext context, {
    required String apkUrl,
    required String versionName,
    required String releaseNotes,
    required bool forceUpdate,
  }) {
    showDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (ctx) => _UpdateDialog(
        apkUrl: apkUrl,
        versionName: versionName,
        releaseNotes: releaseNotes,
        forceUpdate: forceUpdate,
      ),
    );
  }
}

class _UpdateDialog extends StatefulWidget {
  final String apkUrl;
  final String versionName;
  final String releaseNotes;
  final bool forceUpdate;

  const _UpdateDialog({
    required this.apkUrl,
    required this.versionName,
    required this.releaseNotes,
    required this.forceUpdate,
  });

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0;
  String _statusText = '';
  String? _errorText;

  Future<void> _startDownload() async {
    // Solicitar permiso de instalación en Android 8+
    if (!await Permission.requestInstallPackages.isGranted) {
      final status = await Permission.requestInstallPackages.request();
      if (!status.isGranted) {
        setState(() => _errorText = 'Permiso de instalación denegado.\nActívalo en Ajustes > Instalar apps desconocidas.');
        return;
      }
    }

    setState(() {
      _isDownloading = true;
      _progress = 0;
      _statusText = 'Descargando...';
      _errorText = null;
    });

    try {
      final tempDir = await getTemporaryDirectory();
      final apkPath = '${tempDir.path}/tekoplay_update.apk';

      await Dio().download(
        widget.apkUrl,
        apkPath,
        onReceiveProgress: (received, total) {
          if (total > 0 && mounted) {
            setState(() {
              _progress = received / total;
              final mb = (received / 1024 / 1024).toStringAsFixed(1);
              final totalMb = (total / 1024 / 1024).toStringAsFixed(1);
              _statusText = 'Descargando $mb / $totalMb MB';
            });
          }
        },
      );

      if (mounted) setState(() => _statusText = 'Instalando...');
      await OpenFilex.open(apkPath, type: 'application/vnd.android.package-archive');

      if (mounted) Navigator.of(context).pop();
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorText = 'Error al descargar: ${e.message}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorText = 'Error inesperado. Intenta de nuevo.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.forceUpdate && !_isDownloading,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEC7A34).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.system_update, color: Color(0xFFEC7A34), size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Nueva versión', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  if (widget.versionName.isNotEmpty)
                    Text(widget.versionName, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.normal)),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.releaseNotes.isNotEmpty) ...[
              Text(widget.releaseNotes, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 16),
            ],

            if (_isDownloading) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFEC7A34)),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _statusText,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              if (_progress > 0)
                Text(
                  '${(_progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFEC7A34)),
                ),
            ],

            if (_errorText != null)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(_errorText!, style: TextStyle(fontSize: 13, color: Colors.red.shade700)),
              ),
          ],
        ),
        actions: [
          if (!widget.forceUpdate && !_isDownloading)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Ahora no', style: TextStyle(color: Colors.grey.shade600)),
            ),
          if (!_isDownloading)
            ElevatedButton.icon(
              onPressed: _startDownload,
              icon: const Icon(Icons.download_rounded, size: 18),
              label: Text(_errorText != null ? 'Reintentar' : 'Actualizar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEC7A34),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
        ],
      ),
    );
  }
}
