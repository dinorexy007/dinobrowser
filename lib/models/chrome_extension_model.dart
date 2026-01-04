/// Chrome Extension Model
/// 
/// Represents a Chrome extension with full manifest.json support
/// Handles Manifest V2 and V3 formats
library;

import 'dart:convert';

/// Content script configuration from manifest.json
class ContentScriptConfig {
  final List<String> matches;
  final List<String> excludeMatches;
  final List<String> js;
  final List<String> css;
  final String runAt; // document_start, document_end, document_idle
  final bool allFrames;
  final String world; // ISOLATED or MAIN

  ContentScriptConfig({
    required this.matches,
    this.excludeMatches = const [],
    this.js = const [],
    this.css = const [],
    this.runAt = 'document_idle',
    this.allFrames = false,
    this.world = 'ISOLATED',
  });

  factory ContentScriptConfig.fromJson(Map<String, dynamic> json) {
    return ContentScriptConfig(
      matches: List<String>.from(json['matches'] ?? []),
      excludeMatches: List<String>.from(json['exclude_matches'] ?? []),
      js: List<String>.from(json['js'] ?? []),
      css: List<String>.from(json['css'] ?? []),
      runAt: json['run_at'] ?? 'document_idle',
      allFrames: json['all_frames'] ?? false,
      world: json['world'] ?? 'ISOLATED',
    );
  }

  Map<String, dynamic> toJson() => {
    'matches': matches,
    'exclude_matches': excludeMatches,
    'js': js,
    'css': css,
    'run_at': runAt,
    'all_frames': allFrames,
    'world': world,
  };
}

/// Browser action / Action configuration
class ExtensionAction {
  final String? defaultPopup;
  final String? defaultIcon;
  final String? defaultTitle;

  ExtensionAction({
    this.defaultPopup,
    this.defaultIcon,
    this.defaultTitle,
  });

  factory ExtensionAction.fromJson(Map<String, dynamic> json) {
    // Handle icon which can be string or object
    String? iconPath;
    if (json['default_icon'] is String) {
      iconPath = json['default_icon'];
    } else if (json['default_icon'] is Map) {
      // Get largest icon
      final iconMap = json['default_icon'] as Map;
      final sizes = iconMap.keys.map((k) => int.tryParse(k.toString()) ?? 0).toList()..sort();
      if (sizes.isNotEmpty) {
        iconPath = iconMap[sizes.last.toString()];
      }
    }

    return ExtensionAction(
      defaultPopup: json['default_popup'],
      defaultIcon: iconPath,
      defaultTitle: json['default_title'],
    );
  }
}

/// Background script/service worker configuration
class BackgroundConfig {
  final String? serviceWorker; // MV3
  final List<String> scripts;  // MV2
  final bool persistent;

  BackgroundConfig({
    this.serviceWorker,
    this.scripts = const [],
    this.persistent = false,
  });

  factory BackgroundConfig.fromJson(Map<String, dynamic> json) {
    return BackgroundConfig(
      serviceWorker: json['service_worker'],
      scripts: List<String>.from(json['scripts'] ?? []),
      persistent: json['persistent'] ?? false,
    );
  }
}

/// Chrome Extension Model
class ChromeExtensionModel {
  final String id;           // Unique ID (from manifest or generated)
  final String name;
  final String version;
  final String? description;
  final int manifestVersion; // 2 or 3
  final List<String> permissions;
  final List<String> hostPermissions;
  final List<ContentScriptConfig> contentScripts;
  final BackgroundConfig? background;
  final ExtensionAction? action;
  final Map<String, String> icons; // size -> path
  final String? optionsPage;
  final String localPath;    // Path where extension is extracted
  final bool isEnabled;
  final DateTime installedAt;

  // Loaded content - populated when extension is active
  Map<String, String> loadedScripts = {};  // path -> content
  Map<String, String> loadedStyles = {};   // path -> content

  ChromeExtensionModel({
    required this.id,
    required this.name,
    required this.version,
    this.description,
    required this.manifestVersion,
    this.permissions = const [],
    this.hostPermissions = const [],
    this.contentScripts = const [],
    this.background,
    this.action,
    this.icons = const {},
    this.optionsPage,
    required this.localPath,
    this.isEnabled = true,
    DateTime? installedAt,
  }) : installedAt = installedAt ?? DateTime.now();

  /// Create from manifest.json content
  factory ChromeExtensionModel.fromManifest(
    Map<String, dynamic> manifest,
    String localPath, {
    String? overrideId,
  }) {
    // Parse icons
    final iconsRaw = manifest['icons'] as Map<String, dynamic>? ?? {};
    final icons = iconsRaw.map((k, v) => MapEntry(k, v.toString()));

    // Parse content scripts
    final contentScriptsRaw = manifest['content_scripts'] as List? ?? [];
    final contentScripts = contentScriptsRaw
        .map((cs) => ContentScriptConfig.fromJson(cs as Map<String, dynamic>))
        .toList();

    // Parse background
    BackgroundConfig? background;
    if (manifest['background'] != null) {
      background = BackgroundConfig.fromJson(manifest['background']);
    }

    // Parse action (MV3) or browser_action/page_action (MV2)
    ExtensionAction? action;
    final actionJson = manifest['action'] ?? 
                       manifest['browser_action'] ?? 
                       manifest['page_action'];
    if (actionJson != null) {
      action = ExtensionAction.fromJson(actionJson);
    }

    // Permissions (MV2 has permissions, MV3 splits into permissions + host_permissions)
    final permissions = List<String>.from(manifest['permissions'] ?? []);
    final hostPermissions = List<String>.from(manifest['host_permissions'] ?? []);

    // Generate ID if not provided
    final id = overrideId ?? 
               manifest['key'] ?? 
               generateExtensionId(manifest['name'] ?? 'unknown');

    return ChromeExtensionModel(
      id: id,
      name: manifest['name'] ?? 'Unknown Extension',
      version: manifest['version'] ?? '1.0.0',
      description: manifest['description'],
      manifestVersion: manifest['manifest_version'] ?? 2,
      permissions: permissions,
      hostPermissions: hostPermissions,
      contentScripts: contentScripts,
      background: background,
      action: action,
      icons: icons,
      optionsPage: manifest['options_page'] ?? manifest['options_ui']?['page'],
      localPath: localPath,
    );
  }

  /// Generate a unique ID from extension name
  static String generateExtensionId(String name) {
    // Chrome uses a hash-based ID, we'll use a simpler approach
    final cleanName = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final hash = cleanName.hashCode.abs().toRadixString(16);
    return '${cleanName.substring(0, cleanName.length.clamp(0, 16))}$hash';
  }

  /// Get the best icon path
  String? get bestIconPath {
    if (icons.isEmpty) return null;
    // Prefer larger icons
    final sizes = icons.keys.map((k) => int.tryParse(k) ?? 0).toList()..sort();
    if (sizes.isEmpty) return icons.values.first;
    return icons[sizes.last.toString()];
  }

  /// Get full path to a resource
  String getResourcePath(String relativePath) {
    return '$localPath/$relativePath';
  }

  /// Check if extension has popup
  bool get hasPopup => action?.defaultPopup != null;

  /// Check if extension has background script
  bool get hasBackground => 
      background?.serviceWorker != null || 
      (background?.scripts.isNotEmpty ?? false);

  /// Check if extension has content scripts
  bool get hasContentScripts => contentScripts.isNotEmpty;

  /// Create a copy with modified fields
  ChromeExtensionModel copyWith({
    String? id,
    String? name,
    String? version,
    String? description,
    int? manifestVersion,
    List<String>? permissions,
    List<String>? hostPermissions,
    List<ContentScriptConfig>? contentScripts,
    BackgroundConfig? background,
    ExtensionAction? action,
    Map<String, String>? icons,
    String? optionsPage,
    String? localPath,
    bool? isEnabled,
    DateTime? installedAt,
  }) {
    return ChromeExtensionModel(
      id: id ?? this.id,
      name: name ?? this.name,
      version: version ?? this.version,
      description: description ?? this.description,
      manifestVersion: manifestVersion ?? this.manifestVersion,
      permissions: permissions ?? this.permissions,
      hostPermissions: hostPermissions ?? this.hostPermissions,
      contentScripts: contentScripts ?? this.contentScripts,
      background: background ?? this.background,
      action: action ?? this.action,
      icons: icons ?? this.icons,
      optionsPage: optionsPage ?? this.optionsPage,
      localPath: localPath ?? this.localPath,
      isEnabled: isEnabled ?? this.isEnabled,
      installedAt: installedAt ?? this.installedAt,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'version': version,
    'description': description,
    'manifest_version': manifestVersion,
    'permissions': permissions,
    'host_permissions': hostPermissions,
    'content_scripts': contentScripts.map((cs) => cs.toJson()).toList(),
    'icons': icons,
    'options_page': optionsPage,
    'local_path': localPath,
    'is_enabled': isEnabled,
    'installed_at': installedAt.toIso8601String(),
  };

  /// Create from stored JSON
  factory ChromeExtensionModel.fromJson(Map<String, dynamic> json) {
    return ChromeExtensionModel(
      id: json['id'],
      name: json['name'],
      version: json['version'],
      description: json['description'],
      manifestVersion: json['manifest_version'] ?? 3,
      permissions: List<String>.from(json['permissions'] ?? []),
      hostPermissions: List<String>.from(json['host_permissions'] ?? []),
      contentScripts: (json['content_scripts'] as List? ?? [])
          .map((cs) => ContentScriptConfig.fromJson(cs))
          .toList(),
      icons: Map<String, String>.from(json['icons'] ?? {}),
      optionsPage: json['options_page'],
      localPath: json['local_path'],
      isEnabled: json['is_enabled'] ?? true,
      installedAt: DateTime.tryParse(json['installed_at'] ?? '') ?? DateTime.now(),
    );
  }

  @override
  String toString() => 'ChromeExtension($id: $name v$version)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChromeExtensionModel && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// URL Match Pattern Utilities
class MatchPattern {
  /// Check if a URL matches a Chrome extension match pattern
  /// Patterns like: *://*.example.com/*, *://*/* , <all_urls>, https://example.com/*
  static bool matches(String pattern, String url) {
    try {
      // Handle special patterns
      if (pattern == '<all_urls>') return true;
      if (pattern == '*://*/*') return true; // Common "match all" pattern
      if (pattern == 'http://*/*' || pattern == 'https://*/*') {
        final uri = Uri.tryParse(url);
        if (uri == null) return false;
        if (pattern.startsWith('http://') && uri.scheme == 'http') return true;
        if (pattern.startsWith('https://') && uri.scheme == 'https') return true;
        return false;
      }
      
      final uri = Uri.tryParse(url);
      if (uri == null) return false;

      // Split pattern into scheme, host, path
      // Pattern format: scheme://host/path
      final schemeEnd = pattern.indexOf('://');
      if (schemeEnd == -1) return false;
      
      final schemePattern = pattern.substring(0, schemeEnd);
      final rest = pattern.substring(schemeEnd + 3); // Skip "://"
      
      final pathStart = rest.indexOf('/');
      String hostPattern;
      String pathPattern;
      
      if (pathStart == -1) {
        hostPattern = rest;
        pathPattern = '/*';
      } else {
        hostPattern = rest.substring(0, pathStart);
        pathPattern = rest.substring(pathStart);
      }

      // Check scheme (* matches http and https)
      if (schemePattern != '*') {
        if (schemePattern != uri.scheme) {
          return false;
        }
      } else {
        // * only matches http and https, not file, ftp, etc.
        if (uri.scheme != 'http' && uri.scheme != 'https') {
          return false;
        }
      }

      // Check host
      if (hostPattern != '*') {
        if (hostPattern.startsWith('*.')) {
          // Subdomain wildcard: *.example.com
          final baseDomain = hostPattern.substring(2);
          if (uri.host != baseDomain && !uri.host.endsWith('.$baseDomain')) {
            return false;
          }
        } else {
          // Exact host match
          if (hostPattern != uri.host) {
            return false;
          }
        }
      }
      // If hostPattern is *, any host matches

      // Check path with wildcard support
      if (pathPattern != '/*' && pathPattern != '/*') {
        // Convert path pattern to regex
        final pathRegexStr = '^' + pathPattern
            .replaceAll('.', r'\.')
            .replaceAll('*', '.*') + r'$';
        final pathRegex = RegExp(pathRegexStr);
        final urlPath = uri.path.isEmpty ? '/' : uri.path;
        if (!pathRegex.hasMatch(urlPath)) {
          return false;
        }
      }

      return true;
    } catch (e) {
      print('[MatchPattern] Error matching "$pattern" against "$url": $e');
      return false;
    }
  }

  /// Check if URL matches any of the patterns
  static bool matchesAny(List<String> patterns, String url) {
    return patterns.any((p) => matches(p, url));
  }

  /// Check if URL matches patterns but not exclude patterns
  static bool shouldInject(
    List<String> matches,
    List<String> excludeMatches,
    String url,
  ) {
    if (!matchesAny(matches, url)) return false;
    if (excludeMatches.isNotEmpty && matchesAny(excludeMatches, url)) return false;
    return true;
  }
}
