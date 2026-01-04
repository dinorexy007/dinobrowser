/// Workspace Model
/// 
/// Represents a contextual workspace (Study, Coding, Entertainment, etc.)
/// Each workspace has its own filtered bookmarks and history
library;

import 'package:flutter/material.dart';

class WorkspaceModel {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final bool isDefault;
  final DateTime createdAt;

  const WorkspaceModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.isDefault = false,
    required this.createdAt,
  });

  /// Create from database row
  factory WorkspaceModel.fromJson(Map<String, dynamic> json) {
    return WorkspaceModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      icon: _iconFromCode(json['icon_code'] ?? 0xe5f9),
      color: Color(json['color'] ?? 0xFF00FFA3),
      isDefault: json['is_default'] == 1,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  /// Convert to database map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon_code': icon.codePoint,
      'color': color.value,
      'is_default': isDefault ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  static IconData _iconFromCode(int code) {
    // Use predefined icons map instead of dynamic IconData constructor
    // This allows tree-shaking in release builds
    return _iconMap[code] ?? Icons.folder;
  }
  
  static const Map<int, IconData> _iconMap = {
    0xe26d: Icons.folder,           // folder
    0xe94f: Icons.work,             // work
    0xe38b: Icons.home,             // home
    0xe8a4: Icons.shopping_cart,    // shopping_cart
    0xe55c: Icons.music_note,       // music_note
    0xe57f: Icons.movie,            // movie
    0xe8fc: Icons.sports_esports,   // sports_esports
    0xe521: Icons.school,           // school
    0xea6c: Icons.travel_explore,   // travel_explore
    0xf06c: Icons.restaurant,       // restaurant
    0xe8b8: Icons.science,          // science
    0xe2d6: Icons.fitness_center,   // fitness_center
  };

  WorkspaceModel copyWith({
    String? id,
    String? name,
    IconData? icon,
    Color? color,
    bool? isDefault,
    DateTime? createdAt,
  }) {
    return WorkspaceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'Workspace($id: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkspaceModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Default workspaces available in Dino Browser
class DefaultWorkspaces {
  DefaultWorkspaces._();

  static final List<WorkspaceModel> all = [
    WorkspaceModel(
      id: 'default',
      name: 'General',
      icon: Icons.public,
      color: const Color(0xFF00FFA3),
      isDefault: true,
      createdAt: DateTime.now(),
    ),
    WorkspaceModel(
      id: 'study',
      name: 'Study',
      icon: Icons.school,
      color: const Color(0xFF4CC9F0),
      createdAt: DateTime.now(),
    ),
    WorkspaceModel(
      id: 'coding',
      name: 'Coding',
      icon: Icons.code,
      color: const Color(0xFF9D4EDD),
      createdAt: DateTime.now(),
    ),
    WorkspaceModel(
      id: 'entertainment',
      name: 'Entertainment',
      icon: Icons.movie,
      color: const Color(0xFFFF6B6B),
      createdAt: DateTime.now(),
    ),
    WorkspaceModel(
      id: 'work',
      name: 'Work',
      icon: Icons.work,
      color: const Color(0xFFFFB703),
      createdAt: DateTime.now(),
    ),
  ];

  static WorkspaceModel get defaultWorkspace => all.first;
}
