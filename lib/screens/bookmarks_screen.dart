/// Bookmarks Screen
/// 
/// Display saved bookmarks from the database

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/browser_provider.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  List<Map<String, dynamic>> _bookmarks = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }
  
  Future<void> _loadBookmarks() async {
    final provider = context.read<BrowserProvider>();
    final bookmarks = await provider.getBookmarks();
    setState(() {
      _bookmarks = bookmarks;
      _isLoading = false;
    });
  }
  
  Future<void> _deleteBookmark(int id, String url) async {
    final provider = context.read<BrowserProvider>();
    await provider.deleteBookmark(id, url: url);
    await _loadBookmarks();
  }
  
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BrowserProvider>();
    
    return Scaffold(
      backgroundColor: DinoColors.darkBg,
      appBar: AppBar(
        backgroundColor: DinoColors.surfaceBg,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.bookmark, color: DinoColors.cyberGreen),
            SizedBox(width: 12),
            Text('Bookmarks'),
          ],
        ),
        actions: [
          // Add current page to bookmarks
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Current Page',
            onPressed: () async {
              final success = await provider.addBookmark();
              if (context.mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Page added to bookmarks'),
                      backgroundColor: DinoColors.cyberGreen,
                    ),
                  );
                  _loadBookmarks();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Could not add bookmark'),
                      backgroundColor: DinoColors.error,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: DinoColors.cyberGreen),
            )
          : _bookmarks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.bookmark_border,
                        size: 80,
                        color: DinoColors.textMuted,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No Bookmarks Yet',
                        style: TextStyle(
                          color: DinoColors.textSecondary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Save your favorite pages to access them quickly',
                        style: TextStyle(
                          color: DinoColors.textMuted,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _bookmarks.length,
                  itemBuilder: (context, index) {
                    final bookmark = _bookmarks[index];
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        provider.navigateTo(bookmark['url'] ?? '');
                        Navigator.pop(context);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: DinoColors.cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: DinoColors.glassBorder),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: DinoColors.cyberGreen.withAlpha(30),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.bookmark,
                                  color: DinoColors.cyberGreen,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      bookmark['title'] ?? 'Untitled',
                                      style: const TextStyle(
                                        color: DinoColors.textPrimary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _extractDomain(bookmark['url'] ?? ''),
                                      style: const TextStyle(
                                        color: DinoColors.textMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: DinoColors.error),
                                onPressed: () async {
                                  final id = bookmark['id'];
                                  final url = bookmark['url'] as String?;
                                  if (id != null && url != null) {
                                    await _deleteBookmark(id as int, url);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
  
  String _extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.replaceFirst('www.', '');
    } catch (e) {
      return url;
    }
  }
}
