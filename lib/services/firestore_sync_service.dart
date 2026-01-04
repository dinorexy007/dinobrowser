/// Firestore Sync Service
/// 
/// Handles cloud synchronization of user data (history, bookmarks, workspaces)
/// Data is synced to Firestore tied to the user's Firebase account
/// This ensures data persists even after app reinstall
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/history_model.dart';
import 'database_service.dart';

class FirestoreSyncService {
  static final FirestoreSyncService _instance = FirestoreSyncService._internal();
  factory FirestoreSyncService() => _instance;
  FirestoreSyncService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseService _db = DatabaseService();
  
  /// Get current user ID
  String? get _userId => _auth.currentUser?.uid;
  
  /// Check if user is logged in
  bool get isLoggedIn => _userId != null;
  
  // ==================== SYNC TO CLOUD ====================
  
  /// Sync all local data to cloud
  Future<void> syncAllToCloud() async {
    if (!isLoggedIn) return;
    
    await Future.wait([
      syncHistoryToCloud(),
      syncBookmarksToCloud(),
      syncWorkspacesToCloud(),
      syncSpeedDialToCloud(),
    ]);
  }
  
  /// Sync history to Firestore
  Future<void> syncHistoryToCloud() async {
    if (!isLoggedIn) return;
    
    try {
      final history = await _db.getAllHistory(userId: _userId!, limit: 500);
      final batch = _firestore.batch();
      final historyRef = _firestore
          .collection('users')
          .doc(_userId!)
          .collection('history');
      
      for (final entry in history) {
        // Use URL hash as doc ID to prevent duplicates
        final docId = _generateDocId(entry.url);
        final docRef = historyRef.doc(docId);
        
        batch.set(docRef, {
          'url': entry.url,
          'title': entry.title,
          'faviconUrl': entry.faviconUrl,
          'workspaceId': entry.workspaceId,
          'visitedAt': entry.visitedAt.toIso8601String(),
          'syncedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      
      await batch.commit();
    } catch (e) {
      // Silently fail - local data is still preserved
      print('[FirestoreSyncService] History sync failed: $e');
    }
  }
  
  /// Sync bookmarks to Firestore
  Future<void> syncBookmarksToCloud() async {
    if (!isLoggedIn) return;
    
    try {
      final bookmarks = await _db.getBookmarks(userId: _userId!);
      final batch = _firestore.batch();
      final bookmarksRef = _firestore
          .collection('users')
          .doc(_userId!)
          .collection('bookmarks');
      
      for (final bookmark in bookmarks) {
        final url = bookmark['url'] as String? ?? '';
        if (url.isEmpty) continue;
        
        final docId = _generateDocId(url);
        final docRef = bookmarksRef.doc(docId);
        
        batch.set(docRef, {
          'url': url,
          'title': bookmark['title'] ?? 'Untitled',
          'faviconUrl': bookmark['favicon_url'],
          'workspaceId': bookmark['workspace_id'] ?? 'default',
          'createdAt': bookmark['created_at'],
          'syncedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      
      await batch.commit();
    } catch (e) {
      print('[FirestoreSyncService] Bookmarks sync failed: $e');
    }
  }
  
  /// Sync workspaces to Firestore
  Future<void> syncWorkspacesToCloud() async {
    if (!isLoggedIn) return;
    
    try {
      final workspaces = await _db.getWorkspaces(userId: _userId!);
      final batch = _firestore.batch();
      final workspacesRef = _firestore
          .collection('users')
          .doc(_userId!)
          .collection('workspaces');
      
      for (final workspace in workspaces) {
        final docRef = workspacesRef.doc(workspace.id);
        
        batch.set(docRef, {
          'id': workspace.id,
          'name': workspace.name,
          'iconCode': workspace.icon.codePoint,
          'color': workspace.color.value,
          'isDefault': workspace.isDefault,
          'syncedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      
      await batch.commit();
    } catch (e) {
      print('[FirestoreSyncService] Workspaces sync failed: $e');
    }
  }
  
  /// Sync speed dial to Firestore
  Future<void> syncSpeedDialToCloud() async {
    if (!isLoggedIn) return;
    
    try {
      final speedDial = await _db.getSpeedDial(userId: _userId!);
      final batch = _firestore.batch();
      final dialRef = _firestore
          .collection('users')
          .doc(_userId!)
          .collection('speed_dial');
      
      for (final site in speedDial) {
        final url = site['url'] as String? ?? '';
        if (url.isEmpty) continue;
        
        final docId = _generateDocId(url);
        final docRef = dialRef.doc(docId);
        
        batch.set(docRef, {
          'url': url,
          'title': site['title'] ?? '',
          'iconUrl': site['icon_url'],
          'visitCount': site['visit_count'] ?? 0,
          'syncedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      
      await batch.commit();
    } catch (e) {
      print('[FirestoreSyncService] Speed dial sync failed: $e');
    }
  }
  
  // ==================== RESTORE FROM CLOUD ====================
  
  /// Restore all data from cloud to local database
  /// Called after user signs in
  Future<void> restoreFromCloud() async {
    if (!isLoggedIn) return;
    
    await Future.wait([
      restoreHistoryFromCloud(),
      restoreBookmarksFromCloud(),
      restoreSpeedDialFromCloud(),
    ]);
  }
  
  /// Restore history from Firestore
  Future<void> restoreHistoryFromCloud() async {
    if (!isLoggedIn) return;
    
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId!)
          .collection('history')
          .orderBy('visitedAt', descending: true)
          .limit(500)
          .get();
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final history = HistoryModel(
          url: data['url'] ?? '',
          title: data['title'] ?? '',
          faviconUrl: data['faviconUrl'],
          workspaceId: data['workspaceId'] ?? 'default',
          visitedAt: DateTime.tryParse(data['visitedAt'] ?? '') ?? DateTime.now(),
        );
        
        // Add to local DB (will skip duplicates based on URL)
        await _db.addHistory(history, userId: _userId!);
      }
    } catch (e) {
      print('[FirestoreSyncService] History restore failed: $e');
    }
  }
  
  /// Restore bookmarks from Firestore
  Future<void> restoreBookmarksFromCloud() async {
    if (!isLoggedIn) return;
    
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId!)
          .collection('bookmarks')
          .get();
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final url = data['url'] as String? ?? '';
        if (url.isEmpty) continue;
        
        await _db.addBookmark(
          userId: _userId!,
          url: url,
          title: data['title'] ?? 'Untitled',
          faviconUrl: data['faviconUrl'],
          workspaceId: data['workspaceId'] ?? 'default',
        );
      }
    } catch (e) {
      print('[FirestoreSyncService] Bookmarks restore failed: $e');
    }
  }
  
  /// Restore speed dial from Firestore
  Future<void> restoreSpeedDialFromCloud() async {
    if (!isLoggedIn) return;
    
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId!)
          .collection('speed_dial')
          .get();
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final url = data['url'] as String? ?? '';
        if (url.isEmpty) continue;
        
        await _db.updateSpeedDial(
          url,
          data['title'] ?? '',
          data['iconUrl'],
          userId: _userId!,
        );
      }
    } catch (e) {
      print('[FirestoreSyncService] Speed dial restore failed: $e');
    }
  }
  
  // ==================== SINGLE ITEM SYNC ====================
  
  /// Sync a single history entry to cloud
  Future<void> syncHistoryEntry(HistoryModel entry) async {
    if (!isLoggedIn) return;
    
    try {
      final docId = _generateDocId(entry.url);
      await _firestore
          .collection('users')
          .doc(_userId!)
          .collection('history')
          .doc(docId)
          .set({
        'url': entry.url,
        'title': entry.title,
        'faviconUrl': entry.faviconUrl,
        'workspaceId': entry.workspaceId,
        'visitedAt': entry.visitedAt.toIso8601String(),
        'syncedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      // Silently fail
    }
  }
  
  /// Sync a single bookmark to cloud
  Future<void> syncBookmark({
    required String url,
    required String title,
    String? faviconUrl,
    String workspaceId = 'default',
  }) async {
    if (!isLoggedIn) return;
    
    try {
      final docId = _generateDocId(url);
      await _firestore
          .collection('users')
          .doc(_userId!)
          .collection('bookmarks')
          .doc(docId)
          .set({
        'url': url,
        'title': title,
        'faviconUrl': faviconUrl,
        'workspaceId': workspaceId,
        'createdAt': DateTime.now().toIso8601String(),
        'syncedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      // Silently fail
    }
  }
  
  /// Delete a bookmark from cloud
  Future<void> deleteBookmarkFromCloud(String url) async {
    if (!isLoggedIn) return;
    
    try {
      final docId = _generateDocId(url);
      await _firestore
          .collection('users')
          .doc(_userId!)
          .collection('bookmarks')
          .doc(docId)
          .delete();
    } catch (e) {
      // Silently fail
    }
  }
  
  /// Delete a history entry from cloud
  Future<void> deleteHistoryFromCloud(String url) async {
    if (!isLoggedIn) return;
    
    try {
      final docId = _generateDocId(url);
      await _firestore
          .collection('users')
          .doc(_userId!)
          .collection('history')
          .doc(docId)
          .delete();
    } catch (e) {
      // Silently fail
    }
  }
  
  /// Clear all history from cloud
  Future<void> clearHistoryFromCloud() async {
    if (!isLoggedIn) return;
    
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId!)
          .collection('history')
          .get();
      
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      // Silently fail
    }
  }
  
  // ==================== HELPERS ====================
  
  /// Generate a document ID from URL (hash-based)
  String _generateDocId(String url) {
    // Use hashCode for simple deduplication
    return url.hashCode.toRadixString(16);
  }
}
