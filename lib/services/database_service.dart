/// Database Service
/// 
/// Handles all SQLite operations for local data persistence
/// Including history, bookmarks, extensions cache, and workspaces
/// All user data is now isolated by user_id
library;

import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/extension_model.dart';
import '../models/history_model.dart';
import '../models/workspace_model.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;
  static const String _dbName = 'dino_browser.db';
  static const int _dbVersion = 3; // Upgraded for user isolation

  /// Get database instance (lazy initialization)
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  /// Initialize the database
  Future<Database> _initDatabase() async {
    final Directory documentsDir = await getApplicationDocumentsDirectory();
    final String path = join(documentsDir.path, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Create database tables
  Future<void> _onCreate(Database db, int version) async {
    // History table - stores browsing history with screenshots
    await db.execute('''
      CREATE TABLE history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        url TEXT NOT NULL,
        title TEXT NOT NULL,
        favicon_url TEXT,
        screenshot_path TEXT,
        workspace_id TEXT DEFAULT 'default',
        visited_at TEXT NOT NULL
      )
    ''');

    // Bookmarks table
    await db.execute('''
      CREATE TABLE bookmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        url TEXT NOT NULL,
        title TEXT NOT NULL,
        favicon_url TEXT,
        workspace_id TEXT DEFAULT 'default',
        position INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    // Extensions cache table
    await db.execute('''
      CREATE TABLE extensions_cache (
        id INTEGER PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        icon_url TEXT,
        js_code TEXT,
        category TEXT,
        downloads INTEGER DEFAULT 0,
        version TEXT,
        is_enabled INTEGER DEFAULT 0,
        cached_at TEXT NOT NULL
      )
    ''');

    // Workspaces table
    await db.execute('''
      CREATE TABLE workspaces (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        icon_code INTEGER NOT NULL,
        color INTEGER NOT NULL,
        is_default INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    // Speed dial (Roar) table
    await db.execute('''
      CREATE TABLE speed_dial (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        url TEXT NOT NULL,
        title TEXT NOT NULL,
        icon_url TEXT,
        position INTEGER DEFAULT 0,
        visit_count INTEGER DEFAULT 0,
        last_visited TEXT
      )
    ''');

    // Saved pages (Fossil Mode) table
    await db.execute('''
      CREATE TABLE saved_pages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        url TEXT NOT NULL,
        title TEXT NOT NULL,
        html_path TEXT NOT NULL,
        screenshot_path TEXT,
        saved_at TEXT NOT NULL
      )
    ''');

    // Workspace saved pages table (separate from bookmarks)
    await db.execute('''
      CREATE TABLE workspace_pages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        url TEXT NOT NULL,
        title TEXT NOT NULL,
        favicon_url TEXT,
        workspace_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        UNIQUE(url, workspace_id, user_id)
      )
    ''');

    // AI chat messages table
    await db.execute('''
      CREATE TABLE ai_chat_messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        content TEXT NOT NULL,
        is_user INTEGER NOT NULL,
        is_error INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_history_user ON history(user_id)');
    await db.execute('CREATE INDEX idx_history_workspace ON history(workspace_id)');
    await db.execute('CREATE INDEX idx_history_visited ON history(visited_at DESC)');
    await db.execute('CREATE INDEX idx_bookmarks_user ON bookmarks(user_id)');
    await db.execute('CREATE INDEX idx_bookmarks_workspace ON bookmarks(workspace_id)');
    await db.execute('CREATE INDEX idx_extensions_user ON extensions_cache(user_id)');
    await db.execute('CREATE INDEX idx_workspaces_user ON workspaces(user_id)');
    await db.execute('CREATE INDEX idx_speed_dial_user ON speed_dial(user_id)');
    await db.execute('CREATE INDEX idx_saved_pages_user ON saved_pages(user_id)');
    await db.execute('CREATE INDEX idx_workspace_pages_user ON workspace_pages(user_id)');
    await db.execute('CREATE INDEX idx_workspace_pages ON workspace_pages(workspace_id)');
    await db.execute('CREATE INDEX idx_ai_messages_user ON ai_chat_messages(user_id)');
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Migration from version 1 to 2: Add workspace_pages table
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS workspace_pages (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          url TEXT NOT NULL,
          title TEXT NOT NULL,
          favicon_url TEXT,
          workspace_id TEXT NOT NULL,
          created_at TEXT NOT NULL,
          UNIQUE(url, workspace_id)
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_workspace_pages ON workspace_pages(workspace_id)');
    }

    // Migration from version 2 to 3: Add user_id to all tables for user isolation
    if (oldVersion < 3) {
      // Add user_id column to existing tables (default to 'anonymous' for existing data)
      await db.execute('ALTER TABLE history ADD COLUMN user_id TEXT NOT NULL DEFAULT "anonymous"');
      await db.execute('ALTER TABLE bookmarks ADD COLUMN user_id TEXT NOT NULL DEFAULT "anonymous"');
      await db.execute('ALTER TABLE extensions_cache ADD COLUMN user_id TEXT NOT NULL DEFAULT "anonymous"');
      await db.execute('ALTER TABLE workspaces ADD COLUMN user_id TEXT NOT NULL DEFAULT "anonymous"');
      await db.execute('ALTER TABLE speed_dial ADD COLUMN user_id TEXT NOT NULL DEFAULT "anonymous"');
      await db.execute('ALTER TABLE saved_pages ADD COLUMN user_id TEXT NOT NULL DEFAULT "anonymous"');
      await db.execute('ALTER TABLE workspace_pages ADD COLUMN user_id TEXT NOT NULL DEFAULT "anonymous"');
      
      // Create AI chat messages table if it doesn't exist
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ai_chat_messages (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id TEXT NOT NULL DEFAULT 'anonymous',
          content TEXT NOT NULL,
          is_user INTEGER NOT NULL,
          is_error INTEGER DEFAULT 0,
          created_at TEXT NOT NULL
        )
      ''');
      
      // Add user_id to ai_chat_messages if it exists but doesn't have user_id
      try {
        await db.execute('ALTER TABLE ai_chat_messages ADD COLUMN user_id TEXT NOT NULL DEFAULT "anonymous"');
      } catch (e) {
        // Column might already exist
      }

      // Create indexes for user_id columns
      await db.execute('CREATE INDEX IF NOT EXISTS idx_history_user ON history(user_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_bookmarks_user ON bookmarks(user_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_extensions_user ON extensions_cache(user_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_workspaces_user ON workspaces(user_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_speed_dial_user ON speed_dial(user_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_saved_pages_user ON saved_pages(user_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_workspace_pages_user ON workspace_pages(user_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_ai_messages_user ON ai_chat_messages(user_id)');
    }
  }

  // ==================== HISTORY OPERATIONS ====================

  /// Add a new history entry
  Future<int> addHistory(HistoryModel history, {required String userId}) async {
    final db = await database;
    final data = history.toJson();
    data['user_id'] = userId;
    return await db.insert('history', data);
  }

  /// Get history entries for a workspace
  Future<List<HistoryModel>> getHistory({
    required String userId,
    String workspaceId = 'default',
    int limit = 100,
    int offset = 0,
  }) async {
    final db = await database;
    final results = await db.query(
      'history',
      where: 'user_id = ? AND workspace_id = ?',
      whereArgs: [userId, workspaceId],
      orderBy: 'visited_at DESC',
      limit: limit,
      offset: offset,
    );
    return results.map((e) => HistoryModel.fromJson(e)).toList();
  }

  /// Get all history (for Time-Travel view)
  /// Returns deduplicated entries (most recent visit per URL)
  Future<List<HistoryModel>> getAllHistory({required String userId, int limit = 200}) async {
    final db = await database;
    // Use a subquery to get the most recent entry for each URL
    // This prevents showing the same site multiple times in quick succession
    final results = await db.rawQuery('''
      SELECT h.*
      FROM history h
      INNER JOIN (
        SELECT url, MAX(visited_at) as max_visited
        FROM history
        WHERE user_id = ?
        GROUP BY url
      ) latest ON h.url = latest.url AND h.visited_at = latest.max_visited
      WHERE h.user_id = ?
      ORDER BY h.visited_at DESC
      LIMIT ?
    ''', [userId, userId, limit]);
    return results.map((e) => HistoryModel.fromJson(e)).toList();
  }

  /// Delete a history entry
  Future<int> deleteHistory(int id, {required String userId}) async {
    final db = await database;
    return await db.delete('history', where: 'id = ? AND user_id = ?', whereArgs: [id, userId]);
  }

  /// Clear all history for a workspace
  Future<int> clearHistory({required String userId, String? workspaceId}) async {
    final db = await database;
    if (workspaceId != null) {
      return await db.delete(
        'history',
        where: 'user_id = ? AND workspace_id = ?',
        whereArgs: [userId, workspaceId],
      );
    }
    return await db.delete('history', where: 'user_id = ?', whereArgs: [userId]);
  }

  // ==================== EXTENSIONS OPERATIONS ====================

  /// Cache an extension locally
  Future<void> cacheExtension(ExtensionModel extension, {required String userId}) async {
    final db = await database;
    
    // Build data map with only the columns that exist in the local table
    // Note: Local table uses 'cached_at', NOT 'created_at' from the API
    final data = {
      'id': extension.id,
      'user_id': userId,
      'name': extension.name,
      'description': extension.description,
      'icon_url': extension.iconUrl,
      'js_code': extension.jsCode,
      'category': extension.category,
      'downloads': extension.downloads,
      'version': extension.version,
      'is_enabled': extension.isEnabled ? 1 : 0,
      'cached_at': DateTime.now().toIso8601String(),
    };
    
    await db.insert(
      'extensions_cache',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all cached extensions
  Future<List<ExtensionModel>> getCachedExtensions({required String userId}) async {
    final db = await database;
    final results = await db.query('extensions_cache', where: 'user_id = ?', whereArgs: [userId]);
    return results.map((e) => ExtensionModel.fromJson(e)).toList();
  }

  /// Get enabled extensions (for injection)
  Future<List<ExtensionModel>> getEnabledExtensions({required String userId}) async {
    final db = await database;
    final results = await db.query(
      'extensions_cache',
      where: 'user_id = ? AND is_enabled = 1',
      whereArgs: [userId],
    );
    return results.map((e) => ExtensionModel.fromJson(e)).toList();
  }

  /// Toggle extension enabled state
  Future<void> toggleExtension(int id, bool enabled, {required String userId}) async {
    final db = await database;
    await db.update(
      'extensions_cache',
      {'is_enabled': enabled ? 1 : 0},
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
    );
  }

  // ==================== SPEED DIAL OPERATIONS ====================

  /// Get speed dial entries
  Future<List<Map<String, dynamic>>> getSpeedDial({required String userId}) async {
    final db = await database;
    return await db.query(
      'speed_dial',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'visit_count DESC, position ASC',
      limit: 12,
    );
  }

  /// Add or update speed dial entry
  Future<void> updateSpeedDial(String url, String title, String? iconUrl, {required String userId}) async {
    final db = await database;
    
    // Check if URL exists for this user
    final existing = await db.query(
      'speed_dial',
      where: 'user_id = ? AND url = ?',
      whereArgs: [userId, url],
    );

    if (existing.isNotEmpty) {
      // Update visit count
      await db.rawUpdate(
        'UPDATE speed_dial SET visit_count = visit_count + 1, last_visited = ? WHERE user_id = ? AND url = ?',
        [DateTime.now().toIso8601String(), userId, url],
      );
    } else {
      // Insert new entry
      await db.insert('speed_dial', {
        'user_id': userId,
        'url': url,
        'title': title,
        'icon_url': iconUrl,
        'position': 0,
        'visit_count': 1,
        'last_visited': DateTime.now().toIso8601String(),
      });
    }
  }

  // ==================== SAVED PAGES OPERATIONS ====================

  /// Save a page for offline reading (Fossil Mode)
  Future<int> savePage({
    required String userId,
    required String url,
    required String title,
    required String htmlPath,
    String? screenshotPath,
  }) async {
    final db = await database;
    return await db.insert('saved_pages', {
      'user_id': userId,
      'url': url,
      'title': title,
      'html_path': htmlPath,
      'screenshot_path': screenshotPath,
      'saved_at': DateTime.now().toIso8601String(),
    });
  }

  /// Get all saved pages
  Future<List<Map<String, dynamic>>> getSavedPages({required String userId}) async {
    final db = await database;
    return await db.query(
      'saved_pages',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'saved_at DESC',
    );
  }

  /// Delete a saved page
  Future<int> deleteSavedPage(int id, {required String userId}) async {
    final db = await database;
    return await db.delete('saved_pages', where: 'id = ? AND user_id = ?', whereArgs: [id, userId]);
  }

  // ==================== BOOKMARKS OPERATIONS ====================

  /// Add a bookmark (prevents duplicates)
  Future<int> addBookmark({
    required String userId,
    required String url,
    required String title,
    String? faviconUrl,
    String workspaceId = 'default',
  }) async {
    final db = await database;
    
    // Check if already bookmarked to prevent duplicates
    final existing = await db.query(
      'bookmarks',
      where: 'user_id = ? AND url = ? AND workspace_id = ?',
      whereArgs: [userId, url, workspaceId],
    );
    
    if (existing.isNotEmpty) {
      // Already bookmarked, return existing id
      return existing.first['id'] as int;
    }
    
    return await db.insert('bookmarks', {
      'user_id': userId,
      'url': url,
      'title': title,
      'favicon_url': faviconUrl,
      'workspace_id': workspaceId,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Get bookmarks for a workspace
  Future<List<Map<String, dynamic>>> getBookmarks({
    required String userId,
    String workspaceId = 'default',
  }) async {
    final db = await database;
    return await db.query(
      'bookmarks',
      where: 'user_id = ? AND workspace_id = ?',
      whereArgs: [userId, workspaceId],
      orderBy: 'position ASC, created_at DESC',
    );
  }

  /// Delete a bookmark
  Future<int> deleteBookmark(int id, {required String userId}) async {
    final db = await database;
    return await db.delete('bookmarks', where: 'id = ? AND user_id = ?', whereArgs: [id, userId]);
  }

  /// Check if URL is bookmarked
  Future<bool> isBookmarked(String url, {required String userId, String workspaceId = 'default'}) async {
    final db = await database;
    final result = await db.query(
      'bookmarks',
      where: 'user_id = ? AND url = ? AND workspace_id = ?',
      whereArgs: [userId, url, workspaceId],
    );
    return result.isNotEmpty;
  }

  // ==================== WORKSPACE PAGES OPERATIONS ====================

  /// Add page to workspace (separate from bookmarks)
  Future<int> addWorkspacePage({
    required String userId,
    required String url,
    required String title,
    String? faviconUrl,
    required String workspaceId,
  }) async {
    final db = await database;
    
    // Use INSERT OR REPLACE to handle duplicates
    return await db.insert(
      'workspace_pages',
      {
        'user_id': userId,
        'url': url,
        'title': title,
        'favicon_url': faviconUrl,
        'workspace_id': workspaceId,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get saved pages for a workspace
  Future<List<Map<String, dynamic>>> getWorkspacePages(String workspaceId, {required String userId}) async {
    final db = await database;
    return await db.query(
      'workspace_pages',
      where: 'user_id = ? AND workspace_id = ?',
      whereArgs: [userId, workspaceId],
      orderBy: 'created_at DESC',
    );
  }

  /// Delete page from workspace
  Future<int> deleteWorkspacePage(int id, {required String userId}) async {
    final db = await database;
    return await db.delete('workspace_pages', where: 'id = ? AND user_id = ?', whereArgs: [id, userId]);
  }

  // ==================== AI CHAT OPERATIONS ====================

  /// Ensure AI chat table exists (for migration)
  Future<void> ensureAiChatTable() async {
    final db = await database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ai_chat_messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL DEFAULT 'anonymous',
        content TEXT NOT NULL,
        is_user INTEGER NOT NULL,
        is_error INTEGER DEFAULT 0,
        image_url TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    
    // Add image_url column if it doesn't exist (migration)
    try {
      await db.execute('ALTER TABLE ai_chat_messages ADD COLUMN image_url TEXT');
    } catch (e) {
      // Column already exists
    }
  }

  /// Save an AI chat message
  Future<int> saveAiMessage({
    required String userId,
    required String content,
    required bool isUser,
    bool isError = false,
    String? imageUrl,
  }) async {
    final db = await database;
    await ensureAiChatTable();
    
    return await db.insert('ai_chat_messages', {
      'user_id': userId,
      'content': content,
      'is_user': isUser ? 1 : 0,
      'is_error': isError ? 1 : 0,
      'image_url': imageUrl,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Get all AI chat messages
  Future<List<Map<String, dynamic>>> getAiMessages({required String userId, int limit = 100}) async {
    final db = await database;
    await ensureAiChatTable();
    
    return await db.query(
      'ai_chat_messages',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at ASC',
      limit: limit,
    );
  }

  /// Delete a single AI message
  Future<int> deleteAiMessage(int id, {required String userId}) async {
    final db = await database;
    return await db.delete('ai_chat_messages', where: 'id = ? AND user_id = ?', whereArgs: [id, userId]);
  }

  /// Clear all AI chat messages
  Future<int> clearAiMessages({required String userId}) async {
    final db = await database;
    await ensureAiChatTable();
    return await db.delete('ai_chat_messages', where: 'user_id = ?', whereArgs: [userId]);
  }

  // ==================== WORKSPACES OPERATIONS ====================

  /// Get workspaces for user (with defaults if none exist)
  Future<List<WorkspaceModel>> getWorkspaces({required String userId}) async {
    final db = await database;
    final results = await db.query(
      'workspaces',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'is_default DESC, created_at ASC',
    );
    
    if (results.isEmpty) {
      // Create default workspaces for new user
      for (final workspace in DefaultWorkspaces.all) {
        final data = workspace.toJson();
        data['user_id'] = userId;
        await db.insert('workspaces', data);
      }
      // Re-fetch
      final newResults = await db.query(
        'workspaces',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'is_default DESC, created_at ASC',
      );
      return newResults.map((e) => WorkspaceModel.fromJson(e)).toList();
    }
    
    return results.map((e) => WorkspaceModel.fromJson(e)).toList();
  }

  /// Close the database
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
