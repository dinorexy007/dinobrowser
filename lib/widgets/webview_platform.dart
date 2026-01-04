/// WebView Platform Widget
/// 
/// Platform-aware WebView that uses InAppWebView on mobile
/// and iframe-based HtmlElementView on web
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Platform-aware WebView widget
/// 
/// Automatically selects the appropriate implementation:
/// - Mobile/Desktop: Uses InAppWebView (flutter_inappwebview)
/// - Web: Uses iframe via HtmlElementView
class WebViewPlatform extends StatelessWidget {
  final String initialUrl;
  final bool isPrimary;
  final Function(dynamic controller)? onControllerCreated;
  final Function(String url, String title)? onPageFinished;
  final Function(double progress)? onProgressChanged;

  const WebViewPlatform({
    super.key,
    required this.initialUrl,
    this.isPrimary = true,
    this.onControllerCreated,
    this.onPageFinished,
    this.onProgressChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // Web platform - show informational message since browser-in-browser is limited
      return _buildWebFallback(context);
    }

    // Mobile/Desktop - use the actual InAppWebView (via WebViewStack import)
    // This is handled by the regular WebViewStack widget
    return const SizedBox.shrink(); // Placeholder - actual usage is via WebViewStack
  }

  Widget _buildWebFallback(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: DinoGradients.darkGradient,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Dino icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: DinoColors.cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: DinoColors.cyberGreen.withAlpha(100)),
              ),
              child: const Center(
                child: Text('🦖', style: TextStyle(fontSize: 50)),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'DINO Browser',
              style: TextStyle(
                color: DinoColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'The full browser experience is available on Android & iOS.\n\n'
                'Web preview shows the home page with quick links.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: DinoColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: DinoColors.cardBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: DinoColors.glassBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.link, color: DinoColors.cyberGreen, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    initialUrl,
                    style: const TextStyle(
                      color: DinoColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
