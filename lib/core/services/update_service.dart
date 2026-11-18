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

  static Future<bool> canRequestPackageInstalls() async {
    try {
      final res = await _installerChannel.invokeMethod<bool>('canRequestPackageInstalls');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> installApk(String filePath) async {
    try {
      final res = await _installerChannel.invokeMethod<bool>('installApk', {
        'filePath': filePath,
      });
      return res ?? false;
    } catch (e) {
      debugPrint('Install APK error: $e');
      return false;
    }
  }

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
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
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
            content: Text('Update check failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  static void showUpdateModal(BuildContext context, AppUpdateInfo info) {
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UpdateModalContent(info: info),
    );
  }
}

class _UpdateModalContent extends StatefulWidget {
  final AppUpdateInfo info;

  const _UpdateModalContent({required this.info});

  @override
  State<_UpdateModalContent> createState() => _UpdateModalContentState();
}

class _UpdateModalContentState extends State<_UpdateModalContent> with WidgetsBindingObserver {
  bool _isDownloading = false;
  bool _isInstalling = false;
  bool _isDownloaded = false;
  double _progress = 0.0;
  String _statusText = 'Ready to download';
  String? _errorMessage;
  String? _cachedApkPath;
  http.Client? _httpClient;
  Timer? _installSafetyTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkExistingDownload();

    UpdateService._installerChannel.setMethodCallHandler((call) async {
      if (call.method == 'onInstallResumed' && mounted) {
        setState(() {
          _isInstalling = true;
          _statusText = 'Package installer active';
        });
        _startSafetyTimer();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _installSafetyTimer?.cancel();
    _httpClient?.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _installSafetyTimer?.cancel();
      if (_isInstalling || _errorMessage != null) {
        _checkPermissionAndResume();
      }
    }
  }

  Future<void> _checkPermissionAndResume() async {
    final canInstall = await UpdateService.canRequestPackageInstalls();
    if (!mounted) return;

    if (canInstall && _cachedApkPath != null && File(_cachedApkPath!).existsSync()) {
      setState(() {
        _isInstalling = false;
        _isDownloading = false;
        _isDownloaded = true;
        _errorMessage = null;
        _statusText = 'Permission granted. Tap Install to continue.';
      });
    } else {
      setState(() {
        _isInstalling = false;
        _isDownloading = false;
        if (_cachedApkPath != null && File(_cachedApkPath!).existsSync()) {
          _isDownloaded = true;
          _statusText = 'Downloaded. Tap Install Update.';
        }
      });
    }
  }

  Future<void> _checkExistingDownload() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final apkFile = File('${tempDir.path}/smartfleet-update.apk');
      if (await apkFile.exists()) {
        final length = await apkFile.length();
        if (length > 5 * 1024 * 1024) {
          if (mounted) {
            setState(() {
              _isDownloaded = true;
              _cachedApkPath = apkFile.path;
              _statusText = 'Downloaded (${(length / (1024 * 1024)).toStringAsFixed(1)} MB)';
            });
          }
        }
      }
    } catch (_) {}
  }

  void _startSafetyTimer() {
    _installSafetyTimer?.cancel();
    _installSafetyTimer = Timer(const Duration(seconds: 12), () {
      if (mounted && _isInstalling) {
        setState(() {
          _isInstalling = false;
          _isDownloading = false;
          _statusText = 'Installer dismissed. Tap Install to retry.';
        });
      }
    });
  }

  Future<void> _startDownloadAndInstall() async {
    if (_isDownloaded && _cachedApkPath != null) {
      await _launchInstall(_cachedApkPath!);
      return;
    }

    setState(() {
      _isDownloading = true;
      _isInstalling = false;
      _errorMessage = null;
      _progress = 0.0;
      _statusText = 'Connecting to update server...';
    });

    try {
      _httpClient = http.Client();
      final request = http.Request('GET', Uri.parse(widget.info.downloadUrl));
      final response = await _httpClient!.send(request);

      if (response.statusCode != 200) {
        throw 'Server returned HTTP ${response.statusCode}';
      }

      final contentLength = response.contentLength ?? widget.info.apkSizeBytes;
      final tempDir = await getTemporaryDirectory();
      final apkFile = File('${tempDir.path}/smartfleet-update.apk');
      if (await apkFile.exists()) {
        await apkFile.delete();
      }

      final sink = apkFile.openWrite();
      int downloadedBytes = 0;

      await for (final chunk in response.stream) {
        if (!_isDownloading) {
          await sink.close();
          return;
        }
        sink.add(chunk);
        downloadedBytes += chunk.length;
        if (contentLength > 0 && mounted) {
          final p = downloadedBytes / contentLength;
          setState(() {
            _progress = p.clamp(0.0, 1.0);
            final mb = (downloadedBytes / (1024 * 1024)).toStringAsFixed(1);
            final totalMb = (contentLength / (1024 * 1024)).toStringAsFixed(1);
            final percent = (p * 100).toInt();
            _statusText = 'Downloading: $mb / $totalMb MB ($percent%)';
          });
        }
      }

      await sink.flush();
      await sink.close();

      if (!mounted) return;

      setState(() {
        _isDownloading = false;
        _isDownloaded = true;
        _cachedApkPath = apkFile.path;
        _progress = 1.0;
        _statusText = 'Download complete. Launching installer...';
      });

      await _launchInstall(apkFile.path);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _isInstalling = false;
          _errorMessage = 'Download failed: $e';
          _statusText = 'Tap to retry download';
        });
      }
    }
  }

  Future<void> _launchInstall(String filePath) async {
    setState(() {
      _isInstalling = true;
      _statusText = 'Launching Android Package Installer...';
    });

    _startSafetyTimer();

    final success = await UpdateService.installApk(filePath);
    if (!mounted) return;

    if (!success) {
      final canInstall = await UpdateService.canRequestPackageInstalls();
      setState(() {
        _isInstalling = false;
        if (!canInstall) {
          _errorMessage =
              'Permission required: Enable "Allow from this source" in Android Settings, then return here to install.';
          _statusText = 'Awaiting install permission';
        } else {
          _errorMessage =
              'Installer did not launch. Verify storage permissions and retry.';
          _statusText = 'Install error';
        }
      });
    }
  }

  void _cancelDownload() {
    _httpClient?.close();
    setState(() {
      _isDownloading = false;
      _isInstalling = false;
      _progress = 0.0;
      _statusText = 'Download cancelled';
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: colors.border, width: 1.0),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.surfaceAlt,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: colors.border, width: 1.0),
                  ),
                  child: Text(
                    'SYSTEM UPDATE',
                    style: AppTypography.label(colors.brand, fontSize: 11),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.brand,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'v${widget.info.latestVersionName}',
                    style: AppTypography.label(colors.onBrand, fontSize: 11),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close_rounded, size: 22, color: colors.textSecondary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 20,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.border, width: 1.0),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildMetaItem(
                      'PACKAGE SIZE',
                      widget.info.apkSizeBytes > 0
                          ? '${(widget.info.apkSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB'
                          : '9.8 MB',
                      colors,
                    ),
                  ),
                  Container(width: 1, height: 28, color: colors.border),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: _buildMetaItem('CHANNEL', 'Production', colors),
                    ),
                  ),
                  Container(width: 1, height: 28, color: colors.border),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: _buildMetaItem('INTEGRITY', 'SHA-256', colors),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

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
                    'RELEASE NOTES',
                    style: AppTypography.label(colors.textSecondary, fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  ...widget.info.releaseNotes.map(
                    (note) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 4,
                            height: 4,
                            margin: const EdgeInsets.only(top: 7, right: 8),
                            decoration: BoxDecoration(
                              color: colors.brand,
                              shape: BoxShape.circle,
                            ),
                          ),
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

            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.statusDangerContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.statusDanger, width: 1.0),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, color: colors.statusDanger, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: AppTypography.supporting(colors.statusDanger, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_isDownloading) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 6,
                  backgroundColor: colors.surfaceAlt,
                  valueColor: AlwaysStoppedAnimation<Color>(colors.brand),
                ),
              ),
            ],

            const SizedBox(height: 10),

            Text(
              _statusText,
              style: AppTypography.supporting(colors.textSecondary, fontSize: 12),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                if (_isDownloading) ...[
                  Expanded(
                    flex: 1,
                    child: SecondaryButton(
                      label: 'Cancel',
                      height: 52,
                      onPressed: _cancelDownload,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  flex: 2,
                  child: PrimaryButton(
                    label: _isDownloading
                        ? 'Downloading...'
                        : _isInstalling
                            ? 'Installing...'
                            : _isDownloaded
                                ? 'Install Update'
                                : 'Update Now',
                    icon: _isDownloaded ? Icons.system_update_alt_rounded : Icons.download_rounded,
                    isLoading: _isInstalling,
                    height: 52,
                    onPressed: _isInstalling || _isDownloading
                        ? null
                        : _startDownloadAndInstall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaItem(String label, String value, AppColorsExtension colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.label(colors.textSecondary, fontSize: 9),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTypography.section(colors.text, fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
