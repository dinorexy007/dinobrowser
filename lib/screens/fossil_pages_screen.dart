/// Fossil Pages Screen
/// 
/// View all saved pages for offline reading
/// With thumbnails, swipe to delete, and tap to open
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import '../config/theme.dart';
import '../providers/browser_provider.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';

class FossilPagesScreen extends StatefulWidget {
  const FossilPagesScreen({super.key});

  @override
  State<FossilPagesScreen> createState() => _FossilPagesScreenState();
}

class _FossilPagesScreenState extends State<FossilPagesScreen> {
  final DatabaseService _db = DatabaseService();
  final AuthService _authService = AuthService();
  List<Map<String, dynamic>> _savedPages = [];
  bool _isLoading = true;
  
  String get _currentUserId => _authService.currentUser?.uid ?? 'anonymous';

  @override
  void initState() {
    super.initState();
    _loadSavedPages();
  }

  Future<void> _loadSavedPages() async {
    setState(() => _isLoading = true);
    try {
      final pages = await _db.getSavedPages(userId: _currentUserId);
      if (mounted) {
        setState(() {
          _savedPages = pages;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deletePage(int id, String? htmlPath, String? screenshotPath) async {
    // Delete files
    if (htmlPath != null) {
      try {
        await File(htmlPath).delete();
      } catch (e) {
        // File doesn't exist, ignore
      }
    }
    if (screenshotPath != null) {
      try {
        await File(screenshotPath).delete();
      } catch (e) {
        // File doesn't exist, ignore
      }
    }
    
    // Delete from database
    await _db.deleteSavedPage(id, userId: _currentUserId);
    await _loadSavedPages();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🦴 Fossil removed'),
          backgroundColor: DinoColors.surfaceBg,
        ),
      );
    }
  }

  void _openSavedPage(Map<String, dynamic> page) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FossilViewerScreen(
          title: page['title'] ?? 'Saved Page',
          htmlPath: page['html_path'],
          url: page['url'],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DinoColors.darkBg,
      appBar: AppBar(
        backgroundColor: DinoColors.surfaceBg,
        title: const Row(
          children: [
            Text('🦴', style: TextStyle(fontSize: 24)),
            SizedBox(width: 8),
            Text('Fossil Pages'),
          ],
        ),
        actions: [
          if (_savedPages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: DinoColors.error),
              onPressed: () => _showClearAllDialog(),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: DinoColors.cyberGreen),
            )
          : _savedPages.isEmpty
              ? _buildEmptyState()
              : _buildPagesList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: FadeIn(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: DinoColors.cardBg,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Center(
                child: Text(
                  '🦴',
                  style: TextStyle(
                    fontSize: 60,
                    color: DinoColors.textMuted.withAlpha(100),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Fossilized Pages',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: DinoColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Save pages for offline reading\nusing the fossil button',
              style: TextStyle(
                color: DinoColors.textSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPagesList() {
    return RefreshIndicator(
      onRefresh: _loadSavedPages,
      color: DinoColors.cyberGreen,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _savedPages.length,
        itemBuilder: (context, index) {
          final page = _savedPages[index];
          return FadeInUp(
            duration: Duration(milliseconds: 200 + index * 50),
            child: Dismissible(
              key: Key('fossil_${page['id']}'),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: DinoColors.error.withAlpha(50),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.delete, color: DinoColors.error),
              ),
              onDismissed: (_) => _deletePage(
                page['id'],
                page['html_path'],
                page['screenshot_path'],
              ),
              child: _buildPageCard(page),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPageCard(Map<String, dynamic> page) {
    final screenshotPath = page['screenshot_path'] as String?;
    final hasScreenshot = screenshotPath != null && File(screenshotPath).existsSync();
    
    return GestureDetector(
      onTap: () => _openSavedPage(page),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: DinoColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DinoColors.glassBorder),
        ),
        child: Row(
          children: [
            // Thumbnail
            Container(
              width: 80,
              height: 60,
              decoration: BoxDecoration(
                color: DinoColors.surfaceBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: hasScreenshot
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(screenshotPath),
                        fit: BoxFit.cover,
                      ),
                    )
                  : const Center(
                      child: Text('🦴', style: TextStyle(fontSize: 24)),
                    ),
            ),
            
            const SizedBox(width: 12),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    page['title'] ?? 'Untitled',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: DinoColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _extractDomain(page['url'] ?? ''),
                    style: const TextStyle(
                      fontSize: 12,
                      color: DinoColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(page['saved_at']),
                    style: TextStyle(
                      fontSize: 11,
                      color: DinoColors.textMuted.withAlpha(150),
                    ),
                  ),
                ],
              ),
            ),
            
            const Icon(
              Icons.chevron_right,
              color: DinoColors.textMuted,
            ),
          ],
        ),
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

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);
      
      if (diff.inMinutes < 60) {
        return '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        return '${diff.inHours}h ago';
      } else if (diff.inDays < 7) {
        return '${diff.inDays}d ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return dateStr;
    }
  }

  void _showClearAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DinoColors.surfaceBg,
        title: const Text('Clear All Fossils?'),
        content: const Text('This will delete all saved pages. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              for (final page in _savedPages) {
                await _deletePage(
                  page['id'],
                  page['html_path'],
                  page['screenshot_path'],
                );
              }
            },
            child: const Text('Delete All', style: TextStyle(color: DinoColors.error)),
          ),
        ],
      ),
    );
  }
}

/// Screen to view a saved fossil page
class FossilViewerScreen extends StatefulWidget {
  final String title;
  final String? htmlPath;
  final String? url;

  const FossilViewerScreen({
    super.key,
    required this.title,
    this.htmlPath,
    this.url,
  });

  @override
  State<FossilViewerScreen> createState() => _FossilViewerScreenState();
}

class _FossilViewerScreenState extends State<FossilViewerScreen> {
  String? _htmlContent;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHtmlContent();
  }

  Future<void> _loadHtmlContent() async {
    if (widget.htmlPath == null || !File(widget.htmlPath!).existsSync()) {
      setState(() {
        _error = 'File not found';
        _isLoading = false;
      });
      return;
    }

    try {
      final content = await File(widget.htmlPath!).readAsString();
      if (mounted) {
        setState(() {
          _htmlContent = content;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error loading: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DinoColors.darkBg,
      appBar: AppBar(
        backgroundColor: DinoColors.surfaceBg,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
            if (widget.url != null)
              Text(
                widget.url!,
                style: const TextStyle(
                  fontSize: 11,
                  color: DinoColors.textMuted,
                ),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: DinoColors.amberOrange.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Text('🦴', style: TextStyle(fontSize: 14)),
                SizedBox(width: 4),
                Text(
                  'FOSSIL',
                  style: TextStyle(
                    color: DinoColors.amberOrange,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: DinoColors.cyberGreen),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🦴', style: TextStyle(fontSize: 60)),
            const SizedBox(height: 16),
            const Text(
              'Fossil file not found',
              style: TextStyle(
                color: DinoColors.textSecondary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The saved page may have been deleted',
              style: TextStyle(
                color: DinoColors.textMuted.withAlpha(200),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    if (_htmlContent == null || _htmlContent!.isEmpty) {
      return const Center(
        child: Text(
          'No content available',
          style: TextStyle(color: DinoColors.textSecondary),
        ),
      );
    }

    // Render HTML content in a WebView using InAppWebView
    return InAppWebView(
      initialData: InAppWebViewInitialData(
        data: _htmlContent!,
        mimeType: 'text/html',
        encoding: 'utf-8',
        baseUrl: widget.url != null ? WebUri(widget.url!) : null,
      ),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        cacheEnabled: false,
        supportZoom: true,
        builtInZoomControls: true,
        displayZoomControls: false,
        useHybridComposition: true,
      ),
    );
  }
}

