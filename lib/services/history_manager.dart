/// History Manager Service
/// 
/// Handles automatic screenshot capture and history storage
/// for the Time-Travel History feature
/// Now integrates with cloud sync for lifetime persistence
library;

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/history_model.dart';
import 'database_service.dart';
import 'firestore_sync_service.dart';

class HistoryManager {
  static final HistoryManager _instance = HistoryManager._internal();
  factory HistoryManager() => _instance;
  HistoryManager._internal();

  final DatabaseService _db = DatabaseService();
  final FirestoreSyncService _syncService = FirestoreSyncService();
  String? _screenshotsDir;
  
  /// Cooldown to prevent duplicate history entries (URL -> Last recorded time)
  final Map<String, DateTime> _lastVisits = {};
  static const Duration _duplicateThreshold = Duration(seconds: 30);

  /// Initialize the history manager
  /// Creates screenshots directory if needed
  Future<void> initialize() async {
    final appDir = await getApplicationDocumentsDirectory();
    _screenshotsDir = path.join(appDir.path, 'screenshots');
    
    final dir = Directory(_screenshotsDir!);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    
    // Note: We don't auto-cleanup screenshots anymore to keep history permanent
    // User must manually delete history entries they don't want
  }

  /// Record a page visit with screenshot
  /// 
  /// [controller] - WebView controller to capture screenshot from
  /// [url] - Current page URL
  /// [title] - Page title
  /// [userId] - Current user's ID for data isolation
  /// [workspaceId] - Current workspace ID
  Future<HistoryModel?> recordVisit({
    required InAppWebViewController controller,
    required String url,
    required String title,
    required String userId,
    String workspaceId = 'default',
    String? faviconUrl,
  }) async {
    // Don't record blank pages or internal pages
    if (url.isEmpty || url == 'about:blank' || url.startsWith('data:')) {
      return null;
    }

    // Cooldown check
    final now = DateTime.now();
    final visitKey = '$userId:$url'; // User-specific cooldown
    if (_lastVisits.containsKey(visitKey)) {
      final lastVisit = _lastVisits[visitKey]!;
      if (now.difference(lastVisit) < _duplicateThreshold) {
        return null; // Skip duplicate within threshold
      }
    }

    String? screenshotPath;
    
    try {
      // Capture screenshot
      final Uint8List? screenshot = await controller.takeScreenshot(
        screenshotConfiguration: ScreenshotConfiguration(
          compressFormat: CompressFormat.JPEG,
          quality: 50, // Lower quality for storage efficiency
        ),
      );
      
      if (screenshot != null) {
        // Generate unique filename based on timestamp
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        screenshotPath = path.join(_screenshotsDir!, 'ss_$timestamp.jpg');
        
        // Save screenshot to file
        final file = File(screenshotPath);
        await file.writeAsBytes(screenshot);
      }
    } catch (e) {
      // Screenshot capture failed, continue without it
      screenshotPath = null;
    }

    // Create history entry
    final history = HistoryModel(
      url: url,
      title: title.isNotEmpty ? title : _extractDomain(url),
      faviconUrl: faviconUrl,
      screenshotPath: screenshotPath,
      workspaceId: workspaceId,
      userId: userId,
    );

    // Save to database with userId
    final id = await _db.addHistory(history, userId: userId);
    
    // Update speed dial with userId
    await _db.updateSpeedDial(url, history.title, faviconUrl, userId: userId);
    
    // Sync to cloud (fire and forget - don't block browsing)
    _syncService.syncHistoryEntry(history).catchError((_) {});
    
    // Update cooldown map
    _lastVisits[visitKey] = DateTime.now();
    
    return history.copyWith(id: id);
  }

  /// Get history entries grouped by date
  /// Returns a map of date string -> list of history entries
  Future<Map<String, List<HistoryModel>>> getGroupedHistory({
    required String userId,
    String? workspaceId,
    int limit = 200,
  }) async {
    List<HistoryModel> history;
    
    if (workspaceId != null) {
      history = await _db.getHistory(userId: userId, workspaceId: workspaceId, limit: limit);
    } else {
      history = await _db.getAllHistory(userId: userId, limit: limit);
    }

    final grouped = <String, List<HistoryModel>>{};
    
    for (final entry in history) {
      final dateKey = _getDateKey(entry.visitedAt);
      grouped.putIfAbsent(dateKey, () => []);
      grouped[dateKey]!.add(entry);
    }

    return grouped;
  }

  /// Delete a history entry and its screenshot
  Future<void> deleteEntry(HistoryModel entry, {required String userId}) async {
    // Delete screenshot file if exists
    if (entry.screenshotPath != null) {
      final file = File(entry.screenshotPath!);
      if (await file.exists()) {
        await file.delete();
      }
    }
    
    // Delete from database
    if (entry.id != null) {
      await _db.deleteHistory(entry.id!, userId: userId);
    }
  }

  /// Clear all history
  Future<void> clearAll({required String userId, String? workspaceId}) async {
    // Get all history to delete screenshots
    final history = workspaceId != null
        ? await _db.getHistory(userId: userId, workspaceId: workspaceId, limit: 10000)
        : await _db.getAllHistory(userId: userId, limit: 10000);
    
    // Delete screenshot files
    for (final entry in history) {
      if (entry.screenshotPath != null) {
        final file = File(entry.screenshotPath!);
        if (await file.exists()) {
          try {
            await file.delete();
          } catch (e) {
            // Ignore deletion errors
          }
        }
      }
    }
    
    // Clear database
    await _db.clearHistory(userId: userId, workspaceId: workspaceId);
  }

  /// Get human-readable date key
  String _getDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);
    
    if (dateOnly == today) {
      return 'Today';
    } else if (dateOnly == yesterday) {
      return 'Yesterday';
    } else if (now.difference(date).inDays < 7) {
      return _getDayName(date.weekday);
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  /// Get weekday name
  String _getDayName(int weekday) {
    switch (weekday) {
      case 1: return 'Monday';
      case 2: return 'Tuesday';
      case 3: return 'Wednesday';
      case 4: return 'Thursday';
      case 5: return 'Friday';
      case 6: return 'Saturday';
      case 7: return 'Sunday';
      default: return '';
    }
  }

  /// Extract domain from URL
  String _extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.replaceFirst('www.', '');
    } catch (e) {
      return url;
    }
  }
}
