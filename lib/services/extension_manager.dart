/// Extension Manager Service
/// 
/// Central service for managing Chrome extensions in Dino Browser
/// Handles installation, enabling/disabling, uninstallation, and content injection
library;

import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chrome_extension_model.dart';
import 'extension_parser_service.dart';

/// Result of extension operations
class ExtensionOperationResult {
  final bool success;
  final String? message;
  final ChromeExtensionModel? extension;

  ExtensionOperationResult.success({this.extension, this.message})
      : success = true;

  ExtensionOperationResult.failure(this.message)
      : success = false,
        extension = null;
}

/// Extension Manager Service
class ExtensionManager {
  static final ExtensionManager _instance = ExtensionManager._internal();
  factory ExtensionManager() => _instance;
  ExtensionManager._internal();

  final ExtensionParserService _parser = ExtensionParserService();
  
  /// All installed extensions
  final Map<String, ChromeExtensionModel> _extensions = {};
  
  /// Chrome API polyfill script (loaded from assets)
  String? _polyfillScript;
  
  /// Preferences key for storing extension metadata
  static const String _prefsKey = 'dino_chrome_extensions';
  
  /// Get all installed extensions
  List<ChromeExtensionModel> get extensions => _extensions.values.toList();
  
  /// Get enabled extensions only
  List<ChromeExtensionModel> get enabledExtensions => 
      _extensions.values.where((e) => e.isEnabled).toList();
  
  /// Check if manager is initialized
  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// Initialize the extension manager
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      // Load polyfill script
      await _loadPolyfill();
      
      // Load installed extensions from preferences
      await _loadInstalledExtensions();
      
      _initialized = true;
      print('[ExtensionManager] Initialized with ${_extensions.length} extensions');
    } catch (e) {
      print('[ExtensionManager] Initialization error: $e');
      _initialized = true; // Mark as initialized anyway to prevent repeated attempts
    }
  }

  /// Load Chrome API polyfill from assets
  Future<void> _loadPolyfill() async {
    try {
      _polyfillScript = await rootBundle.loadString('assets/js/chrome_api_polyfill.js');
      print('[ExtensionManager] Polyfill loaded (${_polyfillScript!.length} chars)');
    } catch (e) {
      print('[ExtensionManager] Failed to load polyfill: $e');
      // Create minimal polyfill if asset fails to load
      _polyfillScript = '''
        if (!window.chrome) {
          window.chrome = {
            runtime: { sendMessage: function(){}, onMessage: { addListener: function(){} } },
            storage: { local: { get: function(k,c){c({})}, set: function(i,c){c&&c()} } }
          };
        }
      ''';
    }
  }

  /// Load installed extensions from SharedPreferences
  Future<void> _loadInstalledExtensions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_prefsKey);
      
      // First, get saved enabled states
      final Map<String, bool> enabledStates = {};
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> extensionsList = jsonDecode(jsonStr);
        for (final extJson in extensionsList) {
          try {
            final id = extJson['id'] as String?;
            final enabled = extJson['is_enabled'] as bool? ?? true;
            if (id != null) {
              enabledStates[id] = enabled;
            }
          } catch (e) {
            // Ignore invalid entries
          }
        }
      }
      
      // Now scan the disk for actual extension directories
      final extIds = await _parser.listInstalledExtensionIds();
      print('[ExtensionManager] Found ${extIds.length} extension directories on disk');
      
      for (final extId in extIds) {
        try {
          final result = await _parser.reloadExtension(extId);
          if (result.success && result.extension != null) {
            final extension = result.extension!;
            final wasEnabled = enabledStates[extId] ?? true;
            _extensions[extId] = extension.copyWith(isEnabled: wasEnabled);
            print('[ExtensionManager] Loaded: ${extension.name} (${extension.localPath})');
          } else {
            print('[ExtensionManager] Failed to reload: $extId - ${result.errorMessage}');
          }
        } catch (e) {
          print('[ExtensionManager] Error loading $extId: $e');
        }
      }
      
      // Save the updated list
      if (_extensions.isNotEmpty) {
        await _saveExtensions();
      }
      
      print('[ExtensionManager] Loaded ${_extensions.length} extensions');
    } catch (e) {
      print('[ExtensionManager] Error loading extensions: $e');
    }
  }

  /// Save extension metadata to SharedPreferences
  Future<void> _saveExtensions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final extensionsList = _extensions.values.map((e) => e.toJson()).toList();
      await prefs.setString(_prefsKey, jsonEncode(extensionsList));
    } catch (e) {
      print('[ExtensionManager] Error saving extensions: $e');
    }
  }

  /// Install extension from file
  Future<ExtensionOperationResult> installFromFile(File file) async {
    await initialize();
    
    try {
      final result = await _parser.parseExtensionFile(file);
      
      if (!result.success || result.extension == null) {
        return ExtensionOperationResult.failure(result.errorMessage ?? 'Parse failed');
      }
      
      final extension = result.extension!;
      
      // Check if already installed
      if (_extensions.containsKey(extension.id)) {
        // Update existing
        _extensions[extension.id] = extension.copyWith(
          isEnabled: _extensions[extension.id]!.isEnabled,
        );
      } else {
        _extensions[extension.id] = extension;
      }
      
      await _saveExtensions();
      
      return ExtensionOperationResult.success(
        extension: extension,
        message: '${extension.name} installed successfully',
      );
    } catch (e) {
      return ExtensionOperationResult.failure('Installation failed: $e');
    }
  }

  /// Install extension from URL
  Future<ExtensionOperationResult> installFromUrl(String url) async {
    await initialize();
    
    try {
      final result = await _parser.parseExtensionFromUrl(url);
      
      if (!result.success || result.extension == null) {
        return ExtensionOperationResult.failure(result.errorMessage ?? 'Download failed');
      }
      
      final extension = result.extension!;
      _extensions[extension.id] = extension;
      await _saveExtensions();
      
      return ExtensionOperationResult.success(
        extension: extension,
        message: '${extension.name} installed successfully',
      );
    } catch (e) {
      return ExtensionOperationResult.failure('Installation failed: $e');
    }
  }

  /// Enable an extension
  Future<ExtensionOperationResult> enableExtension(String extensionId) async {
    if (!_extensions.containsKey(extensionId)) {
      return ExtensionOperationResult.failure('Extension not found');
    }
    
    _extensions[extensionId] = _extensions[extensionId]!.copyWith(isEnabled: true);
    await _saveExtensions();
    
    return ExtensionOperationResult.success(
      extension: _extensions[extensionId],
      message: '${_extensions[extensionId]!.name} enabled',
    );
  }

  /// Disable an extension
  Future<ExtensionOperationResult> disableExtension(String extensionId) async {
    if (!_extensions.containsKey(extensionId)) {
      return ExtensionOperationResult.failure('Extension not found');
    }
    
    _extensions[extensionId] = _extensions[extensionId]!.copyWith(isEnabled: false);
    await _saveExtensions();
    
    return ExtensionOperationResult.success(
      extension: _extensions[extensionId],
      message: '${_extensions[extensionId]!.name} disabled',
    );
  }

  /// Toggle extension enabled state
  Future<ExtensionOperationResult> toggleExtension(String extensionId) async {
    if (!_extensions.containsKey(extensionId)) {
      return ExtensionOperationResult.failure('Extension not found');
    }
    
    final isCurrentlyEnabled = _extensions[extensionId]!.isEnabled;
    return isCurrentlyEnabled 
        ? await disableExtension(extensionId) 
        : await enableExtension(extensionId);
  }

  /// Uninstall an extension
  Future<ExtensionOperationResult> uninstallExtension(String extensionId) async {
    if (!_extensions.containsKey(extensionId)) {
      return ExtensionOperationResult.failure('Extension not found');
    }
    
    final extension = _extensions[extensionId]!;
    
    // Delete files
    await _parser.deleteExtension(extensionId);
    
    // Remove from memory
    _extensions.remove(extensionId);
    await _saveExtensions();
    
    return ExtensionOperationResult.success(
      message: '${extension.name} uninstalled',
    );
  }

  /// Get extension by ID
  ChromeExtensionModel? getExtension(String extensionId) {
    return _extensions[extensionId];
  }

  /// Get UserScripts for WebView initialization
  /// Includes polyfill + all enabled extension content scripts
  UnmodifiableListView<UserScript> getUserScripts(String url) {
    final scripts = <UserScript>[];
    
    // Add polyfill first (always inject at document start)
    if (_polyfillScript != null) {
      scripts.add(UserScript(
        groupName: 'dino_chrome_polyfill',
        source: _polyfillScript!,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
      ));
    }
    
    // Add enabled extension scripts
    for (final extension in enabledExtensions) {
      for (final contentScript in extension.contentScripts) {
        // Check if URL matches
        if (!MatchPattern.shouldInject(
          contentScript.matches,
          contentScript.excludeMatches,
          url,
        )) {
          continue;
        }
        
        // Determine injection time
        UserScriptInjectionTime injectionTime;
        switch (contentScript.runAt) {
          case 'document_start':
            injectionTime = UserScriptInjectionTime.AT_DOCUMENT_START;
            break;
          case 'document_end':
          case 'document_idle':
          default:
            injectionTime = UserScriptInjectionTime.AT_DOCUMENT_END;
            break;
        }
        
        // Add CSS
        for (final cssPath in contentScript.css) {
          final cssContent = extension.loadedStyles[cssPath];
          if (cssContent != null && cssContent.isNotEmpty) {
            scripts.add(UserScript(
              groupName: 'dino_ext_${extension.id}',
              source: '''
                (function() {
                  var style = document.createElement('style');
                  style.textContent = ${jsonEncode(cssContent)};
                  (document.head || document.documentElement).appendChild(style);
                })();
              ''',
              injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
            ));
          }
        }
        
        // Add JS
        for (final jsPath in contentScript.js) {
          final jsContent = extension.loadedScripts[jsPath];
          if (jsContent != null && jsContent.isNotEmpty) {
            scripts.add(UserScript(
              groupName: 'dino_ext_${extension.id}',
              source: '''
                // Dino Extension: ${extension.name} - $jsPath
                (function() {
                  try {
                    ${jsContent}
                    console.log('[Dino] Extension loaded: ${extension.name}');
                  } catch(e) {
                    console.error('[Dino] Extension error (${extension.name}):', e);
                  }
                })();
              ''',
              injectionTime: injectionTime,
            ));
          }
        }
      }
    }
    
    return UnmodifiableListView(scripts);
  }

  /// Inject scripts into an existing WebView controller
  Future<void> injectIntoWebView(
    InAppWebViewController controller,
    String url,
  ) async {
    await initialize();
    
    // Inject polyfill first
    if (_polyfillScript != null) {
      await controller.evaluateJavascript(source: _polyfillScript!);
    }
    
    // Inject enabled extension scripts
    for (final extension in enabledExtensions) {
      for (final contentScript in extension.contentScripts) {
        // Check if URL matches
        if (!MatchPattern.shouldInject(
          contentScript.matches,
          contentScript.excludeMatches,
          url,
        )) {
          continue;
        }
        
        // Inject CSS
        for (final cssPath in contentScript.css) {
          final cssContent = extension.loadedStyles[cssPath];
          if (cssContent != null) {
            await controller.evaluateJavascript(source: '''
              (function() {
                var style = document.createElement('style');
                style.textContent = ${jsonEncode(cssContent)};
                (document.head || document.documentElement).appendChild(style);
              })();
            ''');
          }
        }
        
        // Inject JS
        for (final jsPath in contentScript.js) {
          final jsContent = extension.loadedScripts[jsPath];
          if (jsContent != null) {
            await controller.evaluateJavascript(source: '''
              // Dino Extension: ${extension.name} - $jsPath
              (function() {
                try {
                  $jsContent
                  console.log('[Dino] Extension injected: ${extension.name}');
                } catch(e) {
                  console.error('[Dino] Extension error (${extension.name}):', e);
                }
              })();
            ''');
          }
        }
      }
    }
  }

  /// Check if any extension should run on a given URL
  bool hasExtensionsForUrl(String url) {
    for (final extension in enabledExtensions) {
      for (final contentScript in extension.contentScripts) {
        if (MatchPattern.shouldInject(
          contentScript.matches,
          contentScript.excludeMatches,
          url,
        )) {
          return true;
        }
      }
    }
    return false;
  }

  /// Get list of extensions that will run on a URL
  List<ChromeExtensionModel> getExtensionsForUrl(String url) {
    final result = <ChromeExtensionModel>[];
    
    for (final extension in enabledExtensions) {
      for (final contentScript in extension.contentScripts) {
        if (MatchPattern.shouldInject(
          contentScript.matches,
          contentScript.excludeMatches,
          url,
        )) {
          result.add(extension);
          break; // Only add once per extension
        }
      }
    }
    
    return result;
  }

  /// Clear all extensions
  Future<void> clearAll() async {
    for (final extId in _extensions.keys.toList()) {
      await _parser.deleteExtension(extId);
    }
    _extensions.clear();
    await _saveExtensions();
  }
}
