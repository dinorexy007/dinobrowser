/// Authentication Provider
/// 
/// State management for Firebase Authentication
/// Provides reactive auth state to the widget tree
/// Email/Password authentication only
library;

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../services/firestore_sync_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirestoreSyncService _syncService = FirestoreSyncService();
  
  User? _user;
  bool _isLoading = false;
  String? _error;
  StreamSubscription<User?>? _authSubscription;

  /// Current authenticated user
  User? get user => _user;
  
  /// Whether user is logged in
  bool get isLoggedIn => _user != null;
  
  /// Loading state for auth operations
  bool get isLoading => _isLoading;
  
  /// Error message if any
  String? get error => _error;
  
  /// User's display name or email
  String get displayName => _user?.displayName ?? _user?.email?.split('@').first ?? 'User';
  
  /// User's email
  String? get email => _user?.email;

  AuthProvider() {
    _init();
  }

  void _init() {
    _user = _authService.currentUser;
    _authSubscription = _authService.authStateChanges.listen((user) {
      _user = user;
      notifyListeners();
    });
  }

  /// Force refresh the current user data from Firebase
  Future<void> refreshUser() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await currentUser.reload();
      _user = FirebaseAuth.instance.currentUser;
      notifyListeners();
    }
  }

  /// Sign up with email and password
  Future<bool> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.signUp(email: email, password: password);
      if (displayName != null && displayName.isNotEmpty) {
        await _authService.updateDisplayName(displayName);
      }
      _isLoading = false;
      notifyListeners();
      
      // Sync data from cloud after signup
      await _restoreAndSyncData();
      
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sign in with email and password
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.signIn(email: email, password: password);
      _isLoading = false;
      notifyListeners();
      
      // Restore data from cloud after login
      await _restoreAndSyncData();
      
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Restore data from cloud and sync local data
  Future<void> _restoreAndSyncData() async {
    try {
      await _syncService.restoreFromCloud();
      await _syncService.syncAllToCloud();
    } catch (e) {
      debugPrint('[AuthProvider] Sync failed: $e');
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _syncService.syncAllToCloud();
    await _authService.signOut();
  }

  /// Send password reset email
  Future<bool> sendPasswordReset(String email) async {
    try {
      await _authService.sendPasswordResetEmail(email);
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
