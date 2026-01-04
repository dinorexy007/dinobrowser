/// Download Manager Service
/// 
/// Handles file downloads with progress tracking and persistence

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;

class DownloadItem {
  final String id;
  final String url;
  final String filename;
  final String savePath;
  final String userId; // Track which user downloaded this
  double progress;
  int totalBytes;
  int downloadedBytes;
  DownloadStatus status;
  DateTime startTime;
  DateTime? completeTime;
  
  DownloadItem({
    required this.id,
    required this.url,
    required this.filename,
    required this.savePath,
    required this.userId,
    this.progress = 0.0,
    this.totalBytes = 0,
    this.downloadedBytes = 0,
    this.status = DownloadStatus.pending,
    DateTime? startTime,
    this.completeTime,
  }) : startTime = startTime ?? DateTime.now();
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'url': url,
      'filename': filename,
      'savePath': savePath,
      'userId': userId,
      'progress': progress,
      'totalBytes': totalBytes,
      'downloadedBytes': downloadedBytes,
      'status': status.index,
      'startTime': startTime.toIso8601String(),
      'completeTime': completeTime?.toIso8601String(),
    };
  }
  
  factory DownloadItem.fromMap(Map<String, dynamic> map) {
    return DownloadItem(
      id: map['id'],
      url: map['url'],
      filename: map['filename'],
      savePath: map['savePath'],
      userId: map['userId'] ?? 'anonymous',
      progress: map['progress'],
      totalBytes: map['totalBytes'],
      downloadedBytes: map['downloadedBytes'],
      status: DownloadStatus.values[map['status']],
      startTime: DateTime.parse(map['startTime']),
      completeTime: map['completeTime'] != null ? DateTime.parse(map['completeTime']) : null,
    );
  }
}

enum DownloadStatus {
  pending,
  downloading,
  completed,
  failed,
  cancelled,
}

class DownloadManager extends ChangeNotifier {
  final List<DownloadItem> _downloads = [];
  Database? _database;
  
  List<DownloadItem> get downloads => List.unmodifiable(_downloads);
  List<DownloadItem> get activeDownloads => 
      _downloads.where((d) => d.status == DownloadStatus.downloading).toList();
  List<DownloadItem> get completedDownloads => 
      _downloads.where((d) => d.status == DownloadStatus.completed).toList();
  
  /// Get downloads for a specific user
  List<DownloadItem> getDownloadsForUser(String userId) {
    return _downloads.where((d) => d.userId == userId).toList();
  }
  
  DownloadManager() {
    _initDatabase();
  }
  
  /// Initialize database
  Future<void> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final dbPath = path.join(databasePath, 'downloads.db');
    
    _database = await openDatabase(
      dbPath,
      version: 2, // Increment version for schema change
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE downloads (
            id TEXT PRIMARY KEY,
            url TEXT,
            filename TEXT,
            savePath TEXT,
            userId TEXT,
            progress REAL,
            totalBytes INTEGER,
            downloadedBytes INTEGER,
            status INTEGER,
            startTime TEXT,
            completeTime TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Add userId column if upgrading from version 1
          await db.execute('ALTER TABLE downloads ADD COLUMN userId TEXT DEFAULT "anonymous"');
        }
      },
    );
    
    // Load existing downloads
    await _loadDownloads();
  }
  
  /// Load downloads from database
  Future<void> _loadDownloads() async {
    if (_database == null) return;
    
    final List<Map<String, dynamic>> maps = await _database!.query('downloads');
    _downloads.clear();
    
    for (final map in maps) {
      final download = DownloadItem.fromMap(map);
      
      // If download was in progress when app closed, mark as failed
      // Don't restart downloads automatically
      if (download.status == DownloadStatus.downloading || 
          download.status == DownloadStatus.pending) {
        download.status = DownloadStatus.failed;
        // Update in database
        await _updateDownload(download);
      }
      
      _downloads.add(download);
    }
    
    notifyListeners();
  }
  
  /// Save download to database
  Future<void> _saveDownload(DownloadItem download) async {
    if (_database == null) return;
    
    await _database!.insert(
      'downloads',
      download.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  /// Update download in database
  Future<void> _updateDownload(DownloadItem download) async {
    if (_database == null) return;
    
    await _database!.update(
      'downloads',
      download.toMap(),
      where: 'id = ?',
      whereArgs: [download.id],
    );
  }
  
  /// Start a new download
  Future<void> startDownload(String url, String filename, {String userId = 'anonymous'}) async {
    // Request storage permission
    final permission = await Permission.storage.request();
    if (!permission.isGranted) {
      debugPrint('[DownloadManager] Storage permission denied');
      return;
    }
    
    // Get downloads directory
    Directory? directory;
    if (Platform.isAndroid) {
      directory = Directory('/storage/emulated/0/Download');
    } else {
      directory = await getDownloadsDirectory();
    }
    
    if (directory == null) {
      debugPrint('[DownloadManager] Could not access downloads directory');
      return;
    }
    
    final savePath = '${directory.path}/$filename';
    final downloadId = DateTime.now().millisecondsSinceEpoch.toString();
    
    final download = DownloadItem(
      id: downloadId,
      url: url,
      filename: filename,
      savePath: savePath,
      userId: userId,
    );
    
    _downloads.add(download);
    await _saveDownload(download);
    notifyListeners();
    
    // Start download in background
    _performDownload(download);
  }
  
  /// Perform the actual download
  Future<void> _performDownload(DownloadItem download) async {
    try {
      download.status = DownloadStatus.downloading;
      await _updateDownload(download);
      notifyListeners();
      
      final request = http.Request('GET', Uri.parse(download.url));
      final response = await request.send();
      
      download.totalBytes = response.contentLength ?? 0;
      
      final file = File(download.savePath);
      final sink = file.openWrite();
      
      // Use for-await loop for proper stream completion
      await for (final chunk in response.stream) {
        download.downloadedBytes += chunk.length;
        download.progress = download.totalBytes > 0
            ? download.downloadedBytes / download.totalBytes
            : 0.0;
        sink.add(chunk);
        notifyListeners();
      }
      
      // Stream completed - close file and mark as complete
      await sink.close();
      download.status = DownloadStatus.completed;
      download.progress = 1.0;
      download.completeTime = DateTime.now();
      await _updateDownload(download);
      debugPrint('[DownloadManager] Download completed: ${download.filename}');
      notifyListeners();
      
    } catch (e) {
      download.status = DownloadStatus.failed;
      await _updateDownload(download);
      debugPrint('[DownloadManager] Download error: $e');
      notifyListeners();
    }
  }
  
  /// Cancel a download
  Future<void> cancelDownload(String id) async {
    final download = _downloads.firstWhere((d) => d.id == id);
    download.status = DownloadStatus.cancelled;
    await _updateDownload(download);
    notifyListeners();
  }
  
  /// Remove a download from list and database
  Future<void> removeDownload(String id) async {
    _downloads.removeWhere((d) => d.id == id);
    if (_database != null) {
      await _database!.delete('downloads', where: 'id = ?', whereArgs: [id]);
    }
    notifyListeners();
  }
  
  /// Clear all completed downloads from list and database
  Future<void> clearCompleted() async {
    final completedIds = _downloads
        .where((d) => d.status == DownloadStatus.completed)
        .map((d) => d.id)
        .toList();
    
    _downloads.removeWhere((d) => d.status == DownloadStatus.completed);
    
    if (_database != null) {
      for (final id in completedIds) {
        await _database!.delete('downloads', where: 'id = ?', whereArgs: [id]);
      }
    }
    notifyListeners();
  }
}
