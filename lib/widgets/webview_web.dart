/// WebView Web Implementation
/// 
/// Uses iframe via HtmlElementView for web platform
library;

import 'package:flutter/material.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
import '../config/theme.dart';

/// Web-specific WebView widget using iframes
class WebViewWeb extends StatefulWidget {
  final String initialUrl;
  final bool isPrimary;
  final Function(dynamic controller)? onControllerCreated;
  final Function(String url, String title)? onPageFinished;
  final Function(double progress)? onProgressChanged;

  const WebViewWeb({
    super.key,
    required this.initialUrl,
    this.isPrimary = true,
    this.onControllerCreated,
    this.onPageFinished,
    this.onProgressChanged,
  });

  @override
  State<WebViewWeb> createState() => _WebViewWebState();
}

class _WebViewWebState extends State<WebViewWeb> {
  late final String _viewId;
  html.IFrameElement? _iframe;
  bool _isLoading = true;
  String _currentUrl = '';

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.initialUrl;
    _viewId = 'webview-${DateTime.now().millisecondsSinceEpoch}';
    _registerView();
  }

  void _registerView() {
    // Register the iframe view factory
    ui_web.platformViewRegistry.registerViewFactory(
      _viewId,
      (int viewId) {
        _iframe = html.IFrameElement()
          ..src = _currentUrl
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..allow = 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture'
          ..allowFullscreen = true;

        // Listen for load events
        _iframe!.onLoad.listen((event) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            widget.onProgressChanged?.call(1.0);
            widget.onPageFinished?.call(_currentUrl, 'Web Page');
          }
        });

        return _iframe!;
      },
    );

    // Create a simple controller wrapper for compatibility
    final controller = WebViewWebController(this);
    widget.onControllerCreated?.call(controller);
  }

  /// Load a new URL in the iframe
  void loadUrl(String url) {
    if (_iframe != null && url.isNotEmpty) {
      setState(() {
        _isLoading = true;
        _currentUrl = url;
      });
      _iframe!.src = url;
      widget.onProgressChanged?.call(0.5);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // The iframe WebView
        HtmlElementView(viewType: _viewId),
        
        // Loading indicator
        if (_isLoading)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              backgroundColor: Colors.transparent,
              valueColor: const AlwaysStoppedAnimation<Color>(
                DinoColors.cyberGreen,
              ),
              minHeight: 3,
            ),
          ),
      ],
    );
  }
}

/// Simple controller wrapper for web WebView
class WebViewWebController {
  final _WebViewWebState _state;

  WebViewWebController(this._state);

  /// Load a URL
  Future<void> loadUrl({required UrlRequestWeb urlRequest}) async {
    _state.loadUrl(urlRequest.url);
  }

  /// Reload the current page
  Future<void> reload() async {
    _state.loadUrl(_state._currentUrl);
  }

  /// Stop loading (not fully supported in iframes)
  Future<void> stopLoading() async {
    // iframes don't have a stop loading mechanism
  }

  /// Go back in history
  Future<void> goBack() async {
    _state._iframe?.contentWindow?.history.back();
  }

  /// Go forward in history
  Future<void> goForward() async {
    _state._iframe?.contentWindow?.history.forward();
  }

  /// Check if can go back (limited in iframes due to security)
  Future<bool> canGoBack() async => false;

  /// Check if can go forward (limited in iframes due to security)
  Future<bool> canGoForward() async => false;

  /// Get page title (limited in iframes due to cross-origin)
  Future<String?> getTitle() async => 'Web Page';

  /// Get page HTML (not supported due to cross-origin restrictions)
  Future<String?> getHtml() async => null;

  /// Take screenshot (not supported on web)
  Future<dynamic> takeScreenshot({dynamic screenshotConfiguration}) async => null;
}

/// URL Request wrapper for web
class UrlRequestWeb {
  final String url;
  UrlRequestWeb({required this.url});
}

/// WebUri wrapper for web compatibility
class WebUriWeb {
  final String _url;
  WebUriWeb(this._url);
  String get url => _url;
  @override
  String toString() => _url;
}
