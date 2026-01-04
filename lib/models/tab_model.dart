/// Tab Model
/// 
/// Represents a browser tab with WebView state
library;

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class TabModel {
  final String id;
  String title;
  String url;
  String? faviconUrl;
  String? screenshotPath;
  bool isLoading;
  double progress;
  bool canGoBack;
  bool canGoForward;
  DateTime createdAt;
  DateTime lastAccessedAt;
  InAppWebViewController? controller;
  
  // KeepAlive to preserve native WebView state across tab switches
  InAppWebViewKeepAlive? keepAlive;

  TabModel({
    required this.id,
    this.title = 'New Tab',
    this.url = 'about:blank',
    this.faviconUrl,
    this.screenshotPath,
    this.isLoading = false,
    this.progress = 0.0,
    this.canGoBack = false,
    this.canGoForward = false,
    DateTime? createdAt,
    DateTime? lastAccessedAt,
    this.controller,
    this.keepAlive,
  })  : createdAt = createdAt ?? DateTime.now(),
        lastAccessedAt = lastAccessedAt ?? DateTime.now();
        // DO NOT auto-initialize keepAlive - it prevents URL loading

  /// Create from JSON (for persistence)
  factory TabModel.fromJson(Map<String, dynamic> json) {
    return TabModel(
      id: json['id'] ?? '',
      title: json['title'] ?? 'New Tab',
      url: json['url'] ?? 'about:blank',
      faviconUrl: json['favicon_url'],
      screenshotPath: json['screenshot_path'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      lastAccessedAt: json['last_accessed_at'] != null
          ? DateTime.tryParse(json['last_accessed_at'])
          : null,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'url': url,
      'favicon_url': faviconUrl,
      'screenshot_path': screenshotPath,
      'created_at': createdAt.toIso8601String(),
      'last_accessed_at': lastAccessedAt.toIso8601String(),
    };
  }

  /// Get display title (shortened if too long)
  String get displayTitle {
    if (title.length > 30) {
      return '${title.substring(0, 27)}...';
    }
    return title.isEmpty ? 'New Tab' : title;
  }

  /// Get domain from URL
  String get domain {
    try {
      final uri = Uri.parse(url);
      return uri.host.replaceFirst('www.', '');
    } catch (e) {
      return url;
    }
  }

  /// Check if this is a blank/new tab
  bool get isBlank => url == 'about:blank' || url.isEmpty;

  /// Update with new values
  TabModel copyWith({
    String? id,
    String? title,
    String? url,
    String? faviconUrl,
    String? screenshotPath,
    bool? isLoading,
    double? progress,
    bool? canGoBack,
    bool? canGoForward,
    DateTime? createdAt,
    DateTime? lastAccessedAt,
    InAppWebViewController? controller,
  }) {
    return TabModel(
      id: id ?? this.id,
      title: title ?? this.title,
      url: url ?? this.url,
      faviconUrl: faviconUrl ?? this.faviconUrl,
      screenshotPath: screenshotPath ?? this.screenshotPath,
      isLoading: isLoading ?? this.isLoading,
      progress: progress ?? this.progress,
      canGoBack: canGoBack ?? this.canGoBack,
      canGoForward: canGoForward ?? this.canGoForward,
      createdAt: createdAt ?? this.createdAt,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      controller: controller ?? this.controller,
    );
  }

  @override
  String toString() => 'Tab($id: $title)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TabModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
