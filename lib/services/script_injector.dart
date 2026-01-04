/// Script Injector Service
/// 
/// Handles fetching, caching, and injecting JavaScript extensions
/// into WebView pages
library;

import 'dart:collection';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../models/extension_model.dart';
import 'api_service.dart';
import 'database_service.dart';
import 'auth_service.dart';

class ScriptInjector {
  static final ScriptInjector _instance = ScriptInjector._internal();
  factory ScriptInjector() => _instance;
  ScriptInjector._internal();

  final ApiService _api = ApiService();
  final DatabaseService _db = DatabaseService();
  final AuthService _authService = AuthService();

  /// Get current user ID for data isolation
  String get _currentUserId => _authService.currentUser?.uid ?? 'anonymous';

  /// Cache of enabled extensions with their scripts
  List<ExtensionModel> _enabledExtensions = [];

  /// Get all enabled extensions (from cache)
  List<ExtensionModel> get enabledExtensions => _enabledExtensions;

  /// Initialize the script injector
  /// Loads enabled extensions from local database
  Future<void> initialize() async {
    _enabledExtensions = await _db.getEnabledExtensions(userId: _currentUserId);
  }

  /// Refresh extensions from the server
  /// Downloads all available extensions and caches them
  Future<List<ExtensionModel>> refreshExtensions() async {
    try {
      final extensions = await _api.getExtensions();
      
      // Fetch script for each extension
      for (final ext in extensions) {
        final cached = await _db.getCachedExtensions(userId: _currentUserId);
        final existing = cached.where((e) => e.id == ext.id).firstOrNull;
        
        // Only fetch script if not already cached or version changed
        if (existing == null || existing.version != ext.version) {
          try {
            final withScript = await _api.getScript(ext.id);
            await _db.cacheExtension(withScript.copyWith(
              isEnabled: existing?.isEnabled ?? false,
            ), userId: _currentUserId);
          } catch (e) {
            // Cache what we have even without script
            await _db.cacheExtension(ext.copyWith(
              isEnabled: existing?.isEnabled ?? false,
            ), userId: _currentUserId);
          }
        }
      }
      
      // Refresh enabled list
      _enabledExtensions = await _db.getEnabledExtensions(userId: _currentUserId);
      return await _db.getCachedExtensions(userId: _currentUserId);
    } catch (e) {
      // Return cached extensions on failure
      return await _db.getCachedExtensions(userId: _currentUserId);
    }
  }

  /// Enable or disable an extension
  Future<void> toggleExtension(int extensionId, bool enabled) async {
    await _db.toggleExtension(extensionId, enabled, userId: _currentUserId);
    _enabledExtensions = await _db.getEnabledExtensions(userId: _currentUserId);
  }

  /// Get UserScripts for WebView initialization
  /// These scripts will be injected when pages load
  /// Appearance extensions (like dark mode) inject at document start
  /// Other extensions inject at document end
  UnmodifiableListView<UserScript> getUserScripts() {
    final scripts = <UserScript>[];
    
    for (final ext in _enabledExtensions) {
      if (ext.jsCode != null && ext.jsCode!.isNotEmpty) {
        // Inject appearance extensions early to prevent flash of unstyled content
        final isAppearanceExtension = ext.category.toLowerCase() == 'appearance';
        
        scripts.add(UserScript(
          groupName: 'dino_extensions',
          source: '''
            // Dino Browser Extension: ${ext.name} v${ext.version}
            (function() {
              try {
                ${ext.jsCode}
                console.log('[Dino] Extension loaded: ${ext.name}');
              } catch(e) {
                console.error('[Dino] Extension error (${ext.name}):', e);
              }
            })();
          ''',
          injectionTime: isAppearanceExtension 
              ? UserScriptInjectionTime.AT_DOCUMENT_START 
              : UserScriptInjectionTime.AT_DOCUMENT_END,
        ));
      }
    }
    
    return UnmodifiableListView(scripts);
  }

  /// Inject scripts into an existing WebView controller
  /// Use this when extensions are enabled after page load
  Future<void> injectScriptsInto(InAppWebViewController controller) async {
    for (final ext in _enabledExtensions) {
      if (ext.jsCode != null && ext.jsCode!.isNotEmpty) {
        await controller.evaluateJavascript(source: '''
          // Dino Browser Extension: ${ext.name} v${ext.version}
          (function() {
            try {
              ${ext.jsCode}
              console.log('[Dino] Extension injected: ${ext.name}');
            } catch(e) {
              console.error('[Dino] Extension error (${ext.name}):', e);
            }
          })();
        ''');
      }
    }
  }

  /// Get a single extension's script and inject it
  Future<bool> injectSingleScript(
    InAppWebViewController controller,
    int extensionId,
  ) async {
    try {
      final ext = await _api.getScript(extensionId);
      
      if (ext.jsCode != null && ext.jsCode!.isNotEmpty) {
        await controller.evaluateJavascript(source: ext.jsCode!);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
