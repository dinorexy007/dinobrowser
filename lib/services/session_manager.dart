/// Session Manager Service
/// 
/// Handles saving and restoring browser sessions using SharedPreferences
/// Saves open tabs, URLs, and current tab indices per workspace
/// Now uses user-specific session keys for data isolation

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  /// Get user-specific session key
  String _getSessionKey(String userId) => 'browser_session_$userId';
  
  /// Save the current browser session for a specific user
  Future<void> saveSession(Map<String, dynamic> sessionData, {required String userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(sessionData);
    await prefs.setString(_getSessionKey(userId), jsonString);
  }
  
  /// Restore the previous browser session for a specific user
  Future<Map<String, dynamic>?> restoreSession({required String userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_getSessionKey(userId));
    
    if (jsonString == null || jsonString.isEmpty) {
      return null;
    }
    
    try {
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      // If decoding fails, clear the corrupted data
      await clearSession(userId: userId);
      return null;
    }
  }
  
  /// Clear the saved session for a specific user
  Future<void> clearSession({required String userId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_getSessionKey(userId));
  }
  
  /// Check if a session exists for a specific user
  Future<bool> hasSession({required String userId}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_getSessionKey(userId));
  }
}
