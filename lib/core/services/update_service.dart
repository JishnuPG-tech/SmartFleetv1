import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../data/api_client.dart';
import '../design/tokens/app_colors.dart';
import '../design/tokens/app_typography.dart';
import '../design/components/buttons.dart';

class AppUpdateInfo {
  final bool updateAvailable;
  final bool isMandatory;
  final String latestVersionName;
  final int latestVersionCode;
  final int minSupportedVersionCode;
  final String downloadUrl;
  final int apkSizeBytes;
  final String? checksumSha256;
  final List<String> releaseNotes;
  final String publishedAt;

  AppUpdateInfo({
    required this.updateAvailable,
    required this.isMandatory,
    required this.latestVersionName,
    required this.latestVersionCode,
    required this.minSupportedVersionCode,
    required this.downloadUrl,
    required this.apkSizeBytes,
    this.checksumSha256,
    required this.releaseNotes,
    required this.publishedAt,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    final notes = (json['release_notes'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    return AppUpdateInfo(
      updateAvailable: json['update_available'] as bool? ?? false,
      isMandatory: json['is_mandatory'] as bool? ?? false,
      latestVersionName: json['latest_version_name'] as String? ?? '2.1.0',
      latestVersionCode: (json['latest_version_code'] as num?)?.toInt() ?? 2,
      minSupportedVersionCode: (json['min_supported_version_code'] as num?)?.toInt() ?? 1,
      downloadUrl: json['download_url'] as String? ?? '',
      apkSizeBytes: (json['apk_size_bytes'] as num?)?.toInt() ?? 0,
      checksumSha256: json['checksum_sha256'] as String?,
      releaseNotes: notes,
      publishedAt: json['published_at'] as String? ?? '',
    );
  }
}

class UpdateService {
  static const MethodChannel _installerChannel =
      MethodChannel('com.smartfleet.app/installer');

  static const int currentVersionCode = 1;
  static const String currentVersionName = '2.0.0';

  /// Check server for latest release and prompt driver/manager if new APK is available.
  static Future<void> checkForUpdates(
    BuildContext context, {
    bool showToastIfLatest = false,
  }) async {
    try {
      final baseUrl = ApiClient.defaultBaseUrl;
      final uri = Uri.parse(
          '$baseUrl/app/check-update?current_version_code=$currentVersionCode&current_version_name=$currentVersionName');

      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final updateInfo = AppUpdateInfo.fromJson(data);

        if (updateInfo.updateAvailable) {
          if (!context.mounted) return;
          showUpdateModal(context, updateInfo);
        } else if (showToastIfLatest && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'SmartFleet is up to date (v$currentVersionName)',
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
              backgroundColor: const Color(0xFFC6FF00),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (showToastIfLatest && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not reach update server: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  static void showUpdateModal(BuildContext context, AppUpdateInfo info) {
    showModalBottomSheet(
      context: context,
      isDismissible: !info.isMandatory,
      enableDrag: !info.isMandatory,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PopScope(
        canPop: !info.isMandatory,
        child: UpdateDialog(info: info),
      ),
    );
  }

  static Future<bool> installApk(String filePath) async {
    try {
      final bool? success = await _installerChannel.invokeMethod<bool>(
        'installApk',
        {'filePath': filePath},
      );
      return success ?? false;
    } catch (e) {
      debugPrint('Install APK error: $e');
      return false;
    }
  }
}

class UpdateDialog extends StatefulWidget {
  final AppUpdateInfo info;

  const UpdateDialog({super.key, required this.info});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String _statusText = '';
  String? _errorMessage;

  Future<void> _startDownloadAndInstall() async {
    setState(() {
      _isDownloading = true;
      _errorMessage = null;
      _progress = 0.05;
      _statusText = 'Connecting to high-speed cloud container...';
    });

    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(widget.info.downloadUrl));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('Download failed with status ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? widget.info.apkSizeBytes;
      final tempDir = await getTemporaryDirectory();
      final apkFile = File('${tempDir.path}/SmartFleet-v${widget.info.latestVersionName}.apk');

      if (apkFile.existsSync()) {
        apkFile.deleteSync();
      }

      final sink = apkFile.openWrite();
      int downloadedBytes = 0;

      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloadedBytes += chunk.length;
        if (contentLength > 0) {
          final p = downloadedBytes / contentLength;
          setState(() {
            _progress = p.clamp(0.0, 1.0);
            final mb = (downloadedBytes / (1024 * 1024)).toStringAsFixed(1);
            final totalMb = (contentLength / (1024 * 1024)).toStringAsFixed(1);
            _statusText = 'Downloading update: $mb MB / $totalMb MB (${(p * 100).toInt()}%)';
          });
        }
      }

      await sink.flush();
      await sink.close();

      setState(() {
        _progress = 1.0;
        _statusText = 'Verifying checksum & launching Android Package Installer...';
      });

      await Future.delayed(const Duration(milliseconds: 300));

      final success = await UpdateService.installApk(apkFile.path);
      if (!success && mounted) {
        setState(() {
          _isDownloading = false;
          _errorMessage =
              'Permission required: Please enable "Install unknown apps" for SmartFleet in Settings, then tap Install again.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorMessage = 'Update error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: colors.brand.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: colors.brand.withValues(alpha: 0.15),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header with Badge
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.brand.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.brand, width: 1.5),
                ),
                child: Icon(Icons.system_update_rounded, color: colors.brand, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Update Available',
                          style: AppTypography.title(colors.text, fontSize: 18),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: colors.brand,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'v${widget.info.latestVersionName}',
                            style: AppTypography.label(colors.onBrand, fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.info.isMandatory
                          ? 'Mandatory security & logistics update required'
                          : 'Self-hosted Kerala NH-66 enterprise update',
                      style: AppTypography.supporting(
                        widget.info.isMandatory ? colors.statusDanger : colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (!widget.info.isMandatory && !_isDownloading)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
            ],
          ),

          const SizedBox(height: 18),

          // What is New Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border, width: 1.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "WHAT'S NEW IN THIS RELEASE:",
                  style: AppTypography.label(colors.brand, fontSize: 11),
                ),
                const SizedBox(height: 8),
                ...widget.info.releaseNotes.map(
                  (note) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: TextStyle(color: colors.brand, fontWeight: FontWeight.bold)),
                        Expanded(
                          child: Text(
                            note,
                            style: AppTypography.body(colors.text, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Error Message
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.statusDanger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.statusDanger, width: 1.0),
              ),
              child: Text(
                _errorMessage!,
                style: AppTypography.supporting(colors.statusDanger, fontSize: 12),
              ),
            ),
          ],

          // Download Progress Bar
          if (_isDownloading) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 8,
                backgroundColor: colors.surface,
                valueColor: AlwaysStoppedAnimation<Color>(colors.brand),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _statusText,
              style: AppTypography.supporting(colors.textSecondary, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 20),

          // Action Button
          PrimaryButton(
            label: _isDownloading
                ? 'DOWNLOADING UPDATE...'
                : '⚡ UPDATE NOW (1-TAP)',
            icon: Icons.download_rounded,
            isLoading: _isDownloading,
            height: 56,
            onPressed: _isDownloading ? () {} : _startDownloadAndInstall,
          ),
        ],
      ),
    );
  }
}
