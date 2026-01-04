/// Feedback Service
/// 
/// Handles user feedback storage in SQLite database

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;

class FeedbackItem {
  final String id;
  final String userId;
  final String message;
  final int rating;
  final DateTime createdAt;
  
  FeedbackItem({
    required this.id,
    required this.userId,
    required this.message,
    this.rating = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'message': message,
      'rating': rating,
      'created_at': createdAt.toIso8601String(),
    };
  }
  
  factory FeedbackItem.fromMap(Map<String, dynamic> map) {
    return FeedbackItem(
      id: map['id'],
      userId: map['user_id'],
      message: map['message'],
      rating: map['rating'] ?? 0,
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}

class FeedbackService extends ChangeNotifier {
  Database? _database;
  final List<FeedbackItem> _feedbackList = [];
  
  List<FeedbackItem> get feedbackList => List.unmodifiable(_feedbackList);
  
  FeedbackService() {
    _initDatabase();
  }
  
  /// Initialize database
  Future<void> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final dbPath = path.join(databasePath, 'feedback.db');
    
    _database = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE feedback (
            id TEXT PRIMARY KEY,
            user_id TEXT,
            message TEXT,
            rating INTEGER,
            created_at TEXT
          )
        ''');
      },
    );
    
    await _loadFeedback();
  }
  
  /// Load feedback from database
  Future<void> _loadFeedback() async {
    if (_database == null) return;
    
    final List<Map<String, dynamic>> maps = await _database!.query('feedback');
    _feedbackList.clear();
    _feedbackList.addAll(maps.map((map) => FeedbackItem.fromMap(map)));
    notifyListeners();
  }
  
  /// Submit feedback
  Future<void> submitFeedback(String userId, String message, {int rating = 0}) async {
    if (_database == null) return;
    
    final feedback = FeedbackItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      message: message,
      rating: rating,
    );
    
    await _database!.insert('feedback', feedback.toMap());
    _feedbackList.add(feedback);
    notifyListeners();
    
    debugPrint('[FeedbackService] Feedback submitted: ${feedback.message}');
  }
  
  /// Get all feedback (for admin)
  Future<List<FeedbackItem>> getAllFeedback() async {
    await _loadFeedback();
    return _feedbackList;
  }
}
