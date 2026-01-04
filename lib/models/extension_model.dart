/// Extension Model
/// 
/// Represents a browser extension fetched from bilalcode.site
/// Used for the Extension Store feature
library;

class ExtensionModel {
  final int id;
  final String name;
  final String description;
  final String? iconUrl;
  final String? jsCode;
  final String category;
  final int downloads;
  final String version;
  final DateTime? createdAt;
  final bool isEnabled;

  ExtensionModel({
    required this.id,
    required this.name,
    required this.description,
    this.iconUrl,
    this.jsCode,
    required this.category,
    this.downloads = 0,
    this.version = '1.0.0',
    this.createdAt,
    this.isEnabled = false,
  });

  /// Create from JSON (API response)
  factory ExtensionModel.fromJson(Map<String, dynamic> json) {
    return ExtensionModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      iconUrl: json['icon_url'],
      jsCode: json['js_code'] ?? json['script'],
      category: json['category'] ?? 'utility',
      downloads: json['downloads'] is int 
          ? json['downloads'] 
          : int.tryParse(json['downloads']?.toString() ?? '0') ?? 0,
      version: json['version'] ?? '1.0.0',
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at']) 
          : null,
      isEnabled: json['is_enabled'] == true || json['is_enabled'] == 1,
    );
  }

  /// Convert to JSON (for local storage)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon_url': iconUrl,
      'js_code': jsCode,
      'category': category,
      'downloads': downloads,
      'version': version,
      // Note: created_at is NOT included here because the local SQLite table
      // uses 'cached_at' which is set separately in DatabaseService.cacheExtension()
      'is_enabled': isEnabled ? 1 : 0,
    };
  }

  /// Create copy with modified fields
  ExtensionModel copyWith({
    int? id,
    String? name,
    String? description,
    String? iconUrl,
    String? jsCode,
    String? category,
    int? downloads,
    String? version,
    DateTime? createdAt,
    bool? isEnabled,
  }) {
    return ExtensionModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconUrl: iconUrl ?? this.iconUrl,
      jsCode: jsCode ?? this.jsCode,
      category: category ?? this.category,
      downloads: downloads ?? this.downloads,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  /// Get category icon
  String get categoryIcon {
    switch (category.toLowerCase()) {
      case 'productivity':
        return '⚡';
      case 'privacy':
        return '🛡️';
      case 'appearance':
        return '🎨';
      case 'social':
        return '💬';
      case 'utility':
      default:
        return '🔧';
    }
  }

  @override
  String toString() => 'Extension($id: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExtensionModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
