/// Browser Tools Service
/// 
/// Provides DOM reading and JavaScript execution capabilities
/// for the AI Agent integration
library;

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Result of a browser tool operation
class BrowserToolResult {
  final bool success;
  final String? data;
  final String? error;

  BrowserToolResult({
    required this.success,
    this.data,
    this.error,
  });

  factory BrowserToolResult.success(String data) {
    return BrowserToolResult(success: true, data: data);
  }

  factory BrowserToolResult.failure(String error) {
    return BrowserToolResult(success: false, error: error);
  }
}

/// Page metadata extracted from the DOM
class PageMetadata {
  final String url;
  final String title;
  final String? description;
  final String? author;
  final List<String> keywords;

  PageMetadata({
    required this.url,
    required this.title,
    this.description,
    this.author,
    this.keywords = const [],
  });

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('URL: $url');
    buffer.writeln('Title: $title');
    if (description != null) buffer.writeln('Description: $description');
    if (author != null) buffer.writeln('Author: $author');
    if (keywords.isNotEmpty) buffer.writeln('Keywords: ${keywords.join(', ')}');
    return buffer.toString();
  }
}

/// Browser Tools for AI Agent
/// 
/// Provides DOM reading and JS execution capabilities
class BrowserTools {
  final InAppWebViewController controller;

  BrowserTools(this.controller);

  /// Get the full text content of the page
  /// 
  /// Returns the innerText of document.body
  Future<BrowserToolResult> getPageText() async {
    try {
      final result = await controller.evaluateJavascript(
        source: 'document.body.innerText',
      );
      
      if (result != null && result.toString().isNotEmpty) {
        // Truncate very long content to avoid overwhelming the AI
        String text = result.toString();
        if (text.length > 10000) {
          text = '${text.substring(0, 10000)}\n\n[Content truncated...]';
        }
        return BrowserToolResult.success(text);
      }
      
      return BrowserToolResult.failure('No text content found');
    } catch (e) {
      return BrowserToolResult.failure('Failed to read page: $e');
    }
  }

  /// Get the currently selected text on the page
  Future<BrowserToolResult> getSelectedText() async {
    try {
      final result = await controller.evaluateJavascript(
        source: 'window.getSelection().toString()',
      );
      
      if (result != null && result.toString().isNotEmpty) {
        return BrowserToolResult.success(result.toString());
      }
      
      return BrowserToolResult.failure('No text selected');
    } catch (e) {
      return BrowserToolResult.failure('Failed to get selection: $e');
    }
  }

  /// Get page metadata (title, URL, description, etc.)
  Future<PageMetadata> getPageMetadata() async {
    try {
      final url = await controller.getUrl();
      final title = await controller.getTitle() ?? 'Untitled';
      
      // Get meta tags
      final description = await controller.evaluateJavascript(
        source: '''
          (function() {
            var meta = document.querySelector('meta[name="description"]');
            return meta ? meta.content : null;
          })()
        ''',
      );
      
      final author = await controller.evaluateJavascript(
        source: '''
          (function() {
            var meta = document.querySelector('meta[name="author"]');
            return meta ? meta.content : null;
          })()
        ''',
      );
      
      final keywords = await controller.evaluateJavascript(
        source: '''
          (function() {
            var meta = document.querySelector('meta[name="keywords"]');
            return meta ? meta.content : '';
          })()
        ''',
      );
      
      return PageMetadata(
        url: url?.toString() ?? '',
        title: title,
        description: description?.toString(),
        author: author?.toString(),
        keywords: keywords?.toString().split(',').map((k) => k.trim()).where((k) => k.isNotEmpty).toList() ?? [],
      );
    } catch (e) {
      return PageMetadata(url: '', title: 'Unknown');
    }
  }

  /// Execute JavaScript on the page
  /// 
  /// IMPORTANT: This should only be called after user permission
  Future<BrowserToolResult> executeJavaScript(String script) async {
    try {
      final result = await controller.evaluateJavascript(source: script);
      return BrowserToolResult.success(result?.toString() ?? 'Script executed');
    } catch (e) {
      return BrowserToolResult.failure('Script execution failed: $e');
    }
  }

  /// Scroll to an element on the page
  Future<BrowserToolResult> scrollToElement(String selector) async {
    final script = '''
      (function() {
        var element = document.querySelector('$selector');
        if (element) {
          element.scrollIntoView({ behavior: 'smooth', block: 'center' });
          return 'Scrolled to element';
        }
        return 'Element not found';
      })()
    ''';
    return executeJavaScript(script);
  }

  /// Click an element on the page
  Future<BrowserToolResult> clickElement(String selector) async {
    final script = '''
      (function() {
        var element = document.querySelector('$selector');
        if (element) {
          element.click();
          return 'Clicked element';
        }
        return 'Element not found';
      })()
    ''';
    return executeJavaScript(script);
  }

  /// Highlight an element on the page
  Future<BrowserToolResult> highlightElement(String selector) async {
    final script = '''
      (function() {
        var element = document.querySelector('$selector');
        if (element) {
          element.style.outline = '3px solid #00FF9D';
          element.style.backgroundColor = 'rgba(0, 255, 157, 0.2)';
          setTimeout(() => {
            element.style.outline = '';
            element.style.backgroundColor = '';
          }, 3000);
          return 'Element highlighted';
        }
        return 'Element not found';
      })()
    ''';
    return executeJavaScript(script);
  }

  /// Fill an input field
  Future<BrowserToolResult> fillInput(String selector, String value) async {
    final escapedValue = value.replaceAll("'", "\\'");
    final script = '''
      (function() {
        var element = document.querySelector('$selector');
        if (element && (element.tagName === 'INPUT' || element.tagName === 'TEXTAREA')) {
          element.value = '$escapedValue';
          element.dispatchEvent(new Event('input', { bubbles: true }));
          return 'Input filled';
        }
        return 'Input element not found';
      })()
    ''';
    return executeJavaScript(script);
  }
}

/// Permission types for AI actions
enum AiPermissionType {
  allowOnce,
  allowForSite,
  deny,
}

/// Show permission dialog for AI actions
/// 
/// Returns the user's permission choice
Future<AiPermissionType> showAiPermissionDialog(
  BuildContext context, {
  required String action,
  String? description,
}) async {
  final result = await showDialog<AiPermissionType>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _AiPermissionDialog(
      action: action,
      description: description,
    ),
  );
  
  return result ?? AiPermissionType.deny;
}

class _AiPermissionDialog extends StatelessWidget {
  final String action;
  final String? description;

  const _AiPermissionDialog({
    required this.action,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF00FF9D), width: 1),
      ),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00FF9D), Color(0xFF00D4AA)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text('🦖', style: TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Dino AI',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dino AI wants to:',
            style: TextStyle(
              color: Colors.white.withAlpha(180),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F1A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2A2A4A)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.touch_app,
                  color: Color(0xFF00FF9D),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    action,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (description != null) ...[
            const SizedBox(height: 8),
            Text(
              description!,
              style: TextStyle(
                color: Colors.white.withAlpha(150),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, AiPermissionType.deny),
          child: Text(
            'Cancel',
            style: TextStyle(color: Colors.white.withAlpha(150)),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, AiPermissionType.allowForSite),
          child: const Text(
            'Allow for site',
            style: TextStyle(color: Color(0xFF00D4AA)),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, AiPermissionType.allowOnce),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00FF9D),
            foregroundColor: const Color(0xFF0F0F1A),
          ),
          child: const Text('Allow'),
        ),
      ],
    );
  }
}
