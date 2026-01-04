/// Downloads Screen
/// 
/// Shows download progress and completed downloads

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:open_file/open_file.dart';
import '../config/theme.dart';
import '../services/download_manager.dart';
import '../providers/auth_provider.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final userId = authProvider.user?.uid ?? 'anonymous';
    
    return Scaffold(
      backgroundColor: DinoColors.darkBg,
      appBar: AppBar(
        title: const Text('Downloads'),
        backgroundColor: DinoColors.surfaceBg,
        elevation: 0,
        actions: [
          Consumer<DownloadManager>(
            builder: (context, manager, _) {
              final userDownloads = manager.getDownloadsForUser(userId);
              final userCompleted = userDownloads.where((d) => d.status == DownloadStatus.completed).toList();
              if (userCompleted.isEmpty) {
                return const SizedBox.shrink();
              }
              return IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () {
                  manager.clearCompleted();
                },
                tooltip: 'Clear completed',
              );
            },
          ),
        ],
      ),
      body: Consumer<DownloadManager>(
        builder: (context, manager, _) {
          final userDownloads = manager.getDownloadsForUser(userId);
          
          if (userDownloads.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.download_outlined,
                    size: 64,
                    color: DinoColors.textMuted.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No downloads yet',
                    style: TextStyle(
                      color: DinoColors.textMuted.withOpacity(0.7),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: userDownloads.length,
            itemBuilder: (context, index) {
              final download = userDownloads[index];
              return _DownloadItem(download: download);
            },
          );
        },
      ),
    );
  }
}

class _DownloadItem extends StatelessWidget {
  final DownloadItem download;

  const _DownloadItem({required this.download});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: DinoColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: DinoColors.glassBorder,
          width: 1,
        ),
      ),
      child: ListTile(
        onTap: download.status == DownloadStatus.completed
            ? () async {
                // Open the downloaded file
                final result = await OpenFile.open(download.savePath);
                if (result.type != ResultType.done) {
                  debugPrint('[Downloads] Failed to open file: ${result.message}');
                }
              }
            : null,
        leading: Icon(
          _getStatusIcon(),
          color: _getStatusColor(),
          size: 28,
        ),
        title: Text(
          download.filename,
          style: const TextStyle(
            color: DinoColors.textPrimary,
            fontSize: 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (download.status == DownloadStatus.downloading) ...[
              LinearProgressIndicator(
                value: download.progress,
                backgroundColor: DinoColors.glassBorder,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  DinoColors.cyberGreen,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(download.progress * 100).toStringAsFixed(0)}% • ${_formatBytes(download.downloadedBytes)} / ${_formatBytes(download.totalBytes)}',
                style: const TextStyle(
                  color: DinoColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ] else
              Text(
                _getStatusText(),
                style: TextStyle(
                  color: _getStatusColor(),
                  fontSize: 12,
                ),
              ),
          ],
        ),
        trailing: download.status == DownloadStatus.downloading
            ? IconButton(
                icon: const Icon(Icons.close, size: 20),
                color: DinoColors.textMuted,
                onPressed: () {
                  context.read<DownloadManager>().cancelDownload(download.id);
                },
                tooltip: 'Cancel',
              )
            : download.status == DownloadStatus.completed
                ? ElevatedButton.icon(
                    onPressed: () async {
                      // Open the downloaded file using url_launcher
                      try {
                        final file = File(download.savePath);
                        if (await file.exists()) {
                          final result = await OpenFile.open(download.savePath);
                          if (result.type != ResultType.done) {
                            debugPrint('[Downloads] OpenFile failed: ${result.message}');
                            // If open_file fails, show instructions
                            if (context.mounted) {
                              final isApk = download.filename.toLowerCase().endsWith('.apk');
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(isApk 
                                    ? 'To install APK: Go to Settings → Apps → DINO → Install unknown apps → Allow'
                                    : 'File saved to: ${download.savePath}'),
                                  backgroundColor: DinoColors.cardBg,
                                  duration: const Duration(seconds: 5),
                                  action: SnackBarAction(
                                    label: 'OK',
                                    textColor: DinoColors.cyberGreen,
                                    onPressed: () {},
                                  ),
                                ),
                              );
                            }
                          }
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('File not found'),
                                backgroundColor: DinoColors.cardBg,
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        debugPrint('[Downloads] Error opening file: $e');
                      }
                    },
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('OPEN'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DinoColors.cyberGreen,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: DinoColors.textMuted,
                    onPressed: () {
                      context.read<DownloadManager>().removeDownload(download.id);
                    },
                    tooltip: 'Delete',
                  ),
      ),
    );
  }

  IconData _getStatusIcon() {
    switch (download.status) {
      case DownloadStatus.downloading:
        return Icons.downloading;
      case DownloadStatus.completed:
        return Icons.check_circle;
      case DownloadStatus.failed:
        return Icons.error;
      case DownloadStatus.cancelled:
        return Icons.cancel;
      default:
        return Icons.pending;
    }
  }

  Color _getStatusColor() {
    switch (download.status) {
      case DownloadStatus.downloading:
        return DinoColors.cyberGreen;
      case DownloadStatus.completed:
        return Colors.green;
      case DownloadStatus.failed:
        return Colors.red;
      case DownloadStatus.cancelled:
        return DinoColors.textMuted;
      default:
        return DinoColors.textSecondary;
    }
  }

  String _getStatusText() {
    switch (download.status) {
      case DownloadStatus.completed:
        return 'Completed • ${_formatBytes(download.totalBytes)}';
      case DownloadStatus.failed:
        return 'Failed';
      case DownloadStatus.cancelled:
        return 'Cancelled';
      default:
        return 'Pending';
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
