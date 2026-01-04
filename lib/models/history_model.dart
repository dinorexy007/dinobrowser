/// History Model
/// 
/// Represents a browsing history entry with screenshot for Time-Travel History
library;

class HistoryModel {
  final int? id;
  final String? userId;
  final String url;
  final String title;
  final String? faviconUrl;
  final String? screenshotPath;
  final String workspaceId;
  final DateTime visitedAt;

  HistoryModel({
    this.id,
    this.userId,
    required this.url,
    required this.title,
    this.faviconUrl,
    this.screenshotPath,
    this.workspaceId = 'default',
    DateTime? visitedAt,
  }) : visitedAt = visitedAt ?? DateTime.now();

  /// Create from database row
  factory HistoryModel.fromJson(Map<String, dynamic> json) {
    return HistoryModel(
      id: json['id'],
      userId: json['user_id'],
      url: json['url'] ?? '',
      title: json['title'] ?? '',
      faviconUrl: json['favicon_url'],
      screenshotPath: json['screenshot_path'],
      workspaceId: json['workspace_id'] ?? 'default',
      visitedAt: json['visited_at'] != null
          ? DateTime.tryParse(json['visited_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  /// Convert to database map
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      'url': url,
      'title': title,
      'favicon_url': faviconUrl,
      'screenshot_path': screenshotPath,
      'workspace_id': workspaceId,
      'visited_at': visitedAt.toIso8601String(),
    };
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

  /// Get time ago string
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(visitedAt);

    if (difference.inDays > 7) {
      return '${visitedAt.day}/${visitedAt.month}/${visitedAt.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  /// Check if visited today
  bool get isToday {
    final now = DateTime.now();
    return visitedAt.year == now.year &&
        visitedAt.month == now.month &&
        visitedAt.day == now.day;
  }

  /// Check if visited yesterday
  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return visitedAt.year == yesterday.year &&
        visitedAt.month == yesterday.month &&
        visitedAt.day == yesterday.day;
  }

  HistoryModel copyWith({
    int? id,
    String? userId,
    String? url,
    String? title,
    String? faviconUrl,
    String? screenshotPath,
    String? workspaceId,
    DateTime? visitedAt,
  }) {
    return HistoryModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      url: url ?? this.url,
      title: title ?? this.title,
      faviconUrl: faviconUrl ?? this.faviconUrl,
      screenshotPath: screenshotPath ?? this.screenshotPath,
      workspaceId: workspaceId ?? this.workspaceId,
      visitedAt: visitedAt ?? this.visitedAt,
    );
  }

  @override
  String toString() => 'History($id: $title)';
}
