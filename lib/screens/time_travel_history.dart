/// Time-Travel History Screen
/// 
/// Instagram-style visual timeline of browsing history
/// with screenshot thumbnails grouped by date
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import '../config/theme.dart';
import '../models/history_model.dart';
import '../providers/browser_provider.dart';
import '../services/history_manager.dart';
import '../services/auth_service.dart';

class TimeTravelHistoryScreen extends StatefulWidget {
  const TimeTravelHistoryScreen({super.key});

  @override
  State<TimeTravelHistoryScreen> createState() => _TimeTravelHistoryScreenState();
}

class _TimeTravelHistoryScreenState extends State<TimeTravelHistoryScreen> {
  final HistoryManager _historyManager = HistoryManager();
  final AuthService _authService = AuthService();
  Map<String, List<HistoryModel>> _groupedHistory = {};
  bool _isLoading = true;
  
  String get _currentUserId => _authService.currentUser?.uid ?? 'anonymous';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final provider = context.read<BrowserProvider>();
    final history = await provider.getGroupedHistory();
    if (mounted) {
      setState(() {
        _groupedHistory = history;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteEntry(HistoryModel entry, String dateKey) async {
    await _historyManager.deleteEntry(entry, userId: _currentUserId);
    setState(() {
      _groupedHistory[dateKey]?.remove(entry);
      if (_groupedHistory[dateKey]?.isEmpty ?? true) {
        _groupedHistory.remove(dateKey);
      }
    });
  }

  Future<void> _clearAllHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DinoColors.surfaceBg,
        title: const Text('Clear All History?'),
        content: const Text(
          'This will permanently delete all browsing history and screenshots. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: DinoColors.error),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _historyManager.clearAll(userId: _currentUserId);
      setState(() {
        _groupedHistory = {};
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DinoColors.darkBg,
      appBar: AppBar(
        backgroundColor: DinoColors.surfaceBg,
        title: Row(
          children: [
            const Icon(
              Icons.access_time,
              color: DinoColors.pterodactylBlue,
              size: 24,
            ),
            const SizedBox(width: 8),
            const Text('Time-Travel History'),
          ],
        ),
        actions: [
          if (_groupedHistory.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Clear History',
              onPressed: _clearAllHistory,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: DinoColors.cyberGreen,
              ),
            )
          : _groupedHistory.isEmpty
              ? _buildEmptyState()
              : _buildHistoryList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: FadeIn(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 80,
              color: DinoColors.textMuted.withAlpha(100),
            ),
            const SizedBox(height: DinoDimens.spacingMd),
            Text(
              'No Time-Travel Data Yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: DinoColors.textMuted,
              ),
            ),
            const SizedBox(height: DinoDimens.spacingSm),
            Text(
              'Your browsing history will appear here\nwith visual snapshots',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    final dateKeys = _groupedHistory.keys.toList();
    
    return ListView.builder(
      padding: const EdgeInsets.all(DinoDimens.spacingMd),
      itemCount: dateKeys.length,
      itemBuilder: (context, index) {
        final dateKey = dateKeys[index];
        final entries = _groupedHistory[dateKey]!;
        
        return FadeInUp(
          duration: Duration(milliseconds: 300 + (index * 50)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date header
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: DinoDimens.spacingMd,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: DinoColors.cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: DinoColors.glassBorder,
                        ),
                      ),
                      child: Text(
                        dateKey,
                        style: const TextStyle(
                          color: DinoColors.cyberGreen,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${entries.length} visits',
                      style: const TextStyle(
                        color: DinoColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Grid of history entries
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.85,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: entries.length,
                itemBuilder: (context, entryIndex) {
                  final entry = entries[entryIndex];
                  return _HistoryCard(
                    entry: entry,
                    onTap: () => _openEntry(entry),
                    onDelete: () => _deleteEntry(entry, dateKey),
                  );
                },
              ),
              
              const SizedBox(height: DinoDimens.spacingMd),
            ],
          ),
        );
      },
    );
  }

  void _openEntry(HistoryModel entry) {
    Navigator.pop(context); // Close history screen first
    final provider = context.read<BrowserProvider>();
    // Use post-frame callback to ensure navigation happens after screen is popped
    WidgetsBinding.instance.addPostFrameCallback((_) {
      provider.navigateTo(entry.url);
    });
  }
}

class _HistoryCard extends StatelessWidget {
  final HistoryModel entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _HistoryCard({
    required this.entry,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: () => _showOptions(context),
      child: Container(
        decoration: BoxDecoration(
          color: DinoColors.cardBg,
          borderRadius: BorderRadius.circular(DinoDimens.radiusMedium),
          border: Border.all(color: DinoColors.glassBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Screenshot or placeholder
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(DinoDimens.radiusMedium - 1),
                ),
                child: entry.screenshotPath != null &&
                        File(entry.screenshotPath!).existsSync()
                    ? Image.file(
                        File(entry.screenshotPath!),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (context, error, stack) =>
                            _buildPlaceholder(),
                      )
                    : _buildPlaceholder(),
              ),
            ),
            
            // Info section
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    style: const TextStyle(
                      color: DinoColors.textPrimary,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.public,
                        size: 12,
                        color: DinoColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          entry.domain,
                          style: const TextStyle(
                            color: DinoColors.textMuted,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        entry.timeAgo,
                        style: const TextStyle(
                          color: DinoColors.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: DinoColors.surfaceBg,
      child: Center(
        child: Icon(
          Icons.web,
          size: 40,
          color: DinoColors.textMuted.withAlpha(80),
        ),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: DinoColors.surfaceBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DinoDimens.radiusLarge),
        ),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(DinoDimens.spacingMd),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_browser, color: DinoColors.cyberGreen),
              title: const Text('Open'),
              onTap: () {
                Navigator.pop(context);
                onTap();
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy, color: DinoColors.textSecondary),
              title: const Text('Copy URL'),
              onTap: () {
                Navigator.pop(context);
                // Copy to clipboard
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: DinoColors.error),
              title: const Text('Delete'),
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }
}
