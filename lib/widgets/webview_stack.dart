/// WebView Stack Widget
/// 
/// Reusable InAppWebView wrapper with JS injection,
/// progress indicator, and screenshot capture
library;

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/browser_provider.dart';
import '../providers/auth_provider.dart';
import '../services/script_injector.dart';
import '../services/extension_manager.dart';
import '../services/download_manager.dart';

class WebViewStack extends StatefulWidget {
  final String initialUrl;
  final bool isPrimary;
  final InAppWebViewKeepAlive? keepAlive;
  final Function(InAppWebViewController)? onControllerCreated;
  final Function(String url, String title)? onPageFinished;
  final Function(double progress)? onProgressChanged;

  const WebViewStack({
    super.key,
    this.initialUrl = 'https://www.google.com',
    this.isPrimary = true,
    this.keepAlive,
    this.onControllerCreated,
    this.onPageFinished,
    this.onProgressChanged,
  });

  @override
  State<WebViewStack> createState() => _WebViewStackState();
}

class _WebViewStackState extends State<WebViewStack> with AutomaticKeepAliveClientMixin {
  InAppWebViewController? _controller;
  final ScriptInjector _scriptInjector = ScriptInjector();
  final ExtensionManager _chromeExtManager = ExtensionManager();
  double _progress = 0.0;
  bool _isLoading = true;
  String _currentUrl = '';
  String _currentTitle = '';
  
  @override
  bool get wantKeepAlive => true; // Keep WebView alive when switching tabs

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Stack(
      children: [
        // WebView - simple URL loading (keepAlive was causing blank screens)
        InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(widget.initialUrl)),
          
          // Initial settings
          initialSettings: InAppWebViewSettings(
            // JavaScript
            javaScriptEnabled: true,
            javaScriptCanOpenWindowsAutomatically: true,
            
            // Media
            mediaPlaybackRequiresUserGesture: false,
            allowsInlineMediaPlayback: true,
            
            // User experience
            supportZoom: true,
            builtInZoomControls: true,
            displayZoomControls: false,
            useHybridComposition: true,
            useShouldOverrideUrlLoading: true,
            useOnDownloadStart: true,
            
            // Performance
            cacheEnabled: true,
            
            // Security - allow mixed content for compatibility
            mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
            
            // Desktop mode option
            preferredContentMode: UserPreferredContentMode.MOBILE,
            
            // Other settings
            transparentBackground: false,
            disableContextMenu: false,
            
            // Enable popups to open in new windows/tabs
            supportMultipleWindows: true,
            
            // Incognito mode - set to false to prevent WebView recreation
            // Raptor Mode will use separate screen with dedicated incognito WebView
            incognito: false,
          ),
          
          // Inject extension scripts
          initialUserScripts: _scriptInjector.getUserScripts(),
          
          // Controller created
          onWebViewCreated: (controller) {
            _controller = controller;
            widget.onControllerCreated?.call(controller);
            
            if (widget.isPrimary) {
              context.read<BrowserProvider>().updateCurrentTab(
                controller: controller,
              );
            }
          },
          
          // Page started loading
          onLoadStart: (controller, url) {
            setState(() {
              _isLoading = true;
              _currentUrl = url?.toString() ?? '';
            });
            
            if (widget.isPrimary) {
              context.read<BrowserProvider>().updateCurrentTab(
                url: _currentUrl,
                isLoading: true,
              );
            }
          },
          
          // Page finished loading
          onLoadStop: (controller, url) async {
            setState(() {
              _isLoading = false;
              _currentUrl = url?.toString() ?? '';
            });
            
            // Get page title
            final title = await controller.getTitle();
            setState(() {
              _currentTitle = title ?? '';
            });
            
            // Check navigation state
            final canGoBack = await controller.canGoBack();
            final canGoForward = await controller.canGoForward();
            
            if (widget.isPrimary) {
              final provider = context.read<BrowserProvider>();
              provider.updateCurrentTab(
                url: _currentUrl,
                title: _currentTitle,
                isLoading: false,
                canGoBack: canGoBack,
                canGoForward: canGoForward,
              );
              
              // Record to history
              provider.recordHistory();
            }
            
            // Inject extension scripts on every page load
            // 1. Dino extensions (simple JS scripts)
            await _scriptInjector.initialize();
            if (_scriptInjector.enabledExtensions.isNotEmpty) {
              await _scriptInjector.injectScriptsInto(controller);
            }
            
            // 2. Chrome extensions (content scripts with URL matching)
            await _chromeExtManager.initialize();
            debugPrint('[WebView] Chrome extensions: ${_chromeExtManager.extensions.length} installed, ${_chromeExtManager.enabledExtensions.length} enabled');
            debugPrint('[WebView] Checking URL: $_currentUrl');
            
            for (final ext in _chromeExtManager.enabledExtensions) {
              debugPrint('[WebView] Extension: ${ext.name}');
              debugPrint('[WebView]   - localPath: ${ext.localPath}');
              debugPrint('[WebView]   - Content scripts: ${ext.contentScripts.length}');
              debugPrint('[WebView]   - Loaded JS files: ${ext.loadedScripts.length}');
              debugPrint('[WebView]   - Loaded CSS files: ${ext.loadedStyles.length}');
              for (final cs in ext.contentScripts) {
                debugPrint('[WebView]   - Matches: ${cs.matches}');
              }
            }
            
            if (_chromeExtManager.hasExtensionsForUrl(_currentUrl)) {
              debugPrint('[WebView] Injecting extensions for URL: $_currentUrl');
              await _chromeExtManager.injectIntoWebView(controller, _currentUrl);
              debugPrint('[WebView] Extension injection complete');
            } else {
              debugPrint('[WebView] No extensions match URL: $_currentUrl');
            }
            
            widget.onPageFinished?.call(_currentUrl, _currentTitle);
          },
          
          // Progress changed
          onProgressChanged: (controller, progress) {
            setState(() {
              _progress = progress / 100.0;
            });
            
            if (widget.isPrimary) {
              context.read<BrowserProvider>().updateCurrentTab(
                progress: _progress,
              );
            }
            
            widget.onProgressChanged?.call(_progress);
          },
          
          // Handle downloads
          onDownloadStartRequest: (controller, downloadStartRequest) async {
            final url = downloadStartRequest.url.toString();
            final filename = downloadStartRequest.suggestedFilename ?? 'download_${DateTime.now().millisecondsSinceEpoch}';
            debugPrint('[WebView] Download requested: $url');
            
            // Get download manager from provider context
            try {
              final downloadManager = context.read<DownloadManager>();
              final authProvider = context.read<AuthProvider>();
              final userId = authProvider.user?.uid ?? 'anonymous';
              await downloadManager.startDownload(url, filename, userId: userId);
              
              // Show snackbar with VIEW button
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Downloading: $filename'),
                    backgroundColor: DinoColors.cardBg,
                    duration: const Duration(seconds: 3),
                    action: SnackBarAction(
                      label: 'VIEW',
                      textColor: DinoColors.cyberGreen,
                      onPressed: () {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        Navigator.pushNamed(context, '/downloads');
                      },
                    ),
                  ),
                );
              }
            } catch (e) {
              debugPrint('[WebView] Download error: $e');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Download failed: ${e.toString()}'),
                    backgroundColor: DinoColors.cardBg,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            }
          },
          
          // Title changed
          onTitleChanged: (controller, title) {
            setState(() {
              _currentTitle = title ?? '';
            });
            
            if (widget.isPrimary) {
              context.read<BrowserProvider>().updateCurrentTab(
                title: _currentTitle,
              );
            }
          },
          
          // Handle URL loading (for deep links, popups, target=_blank, etc.)
          shouldOverrideUrlLoading: (controller, navigationAction) async {
            final url = navigationAction.request.url?.toString() ?? '';
            final isNewWindow = navigationAction.isForMainFrame == false;
            final isBlankTarget = navigationAction.iosWKNavigationType == IOSWKNavigationType.LINK_ACTIVATED ||
                                  navigationAction.androidIsRedirect == false;
            
            debugPrint('[WebView] Navigation: $url, isNewWindow: $isNewWindow, isMainFrame: ${navigationAction.isForMainFrame}');
            
            // Handle special URLs
            if (url.startsWith('tel:') || 
                url.startsWith('mailto:') ||
                url.startsWith('sms:') ||
                url.startsWith('intent:') ||
                url.startsWith('market:')) {
              // Cancel these - could launch external app here
              debugPrint('[WebView] Blocking special URL: $url');
              return NavigationActionPolicy.CANCEL;
            }
            
            // Handle target="_blank" or new window requests - open in new tab
            if (isNewWindow && url.isNotEmpty && mounted) {
              debugPrint('[WebView] Opening in new tab (target=_blank): $url');
              final provider = context.read<BrowserProvider>();
              provider.createNewTab(url: url);
              return NavigationActionPolicy.CANCEL; // Don't load in current WebView
            }
            
            return NavigationActionPolicy.ALLOW;
          },
          
          // Console message for debugging extensions
          onConsoleMessage: (controller, consoleMessage) {
            debugPrint('[WebView Console] ${consoleMessage.message}');
          },
          
          // SSL error handling
          onReceivedServerTrustAuthRequest: (controller, challenge) async {
            return ServerTrustAuthResponse(
              action: ServerTrustAuthResponseAction.PROCEED,
            );
          },
          
          // Handle load errors to prevent freezing
          onLoadError: (controller, url, code, message) async {
            debugPrint('[WebView] Load error: $url - Code: $code, Message: $message');
            setState(() {
              _isLoading = false;
            });
          },
          
          // Update navigation state when history changes
          onUpdateVisitedHistory: (controller, url, isReload) async {
            final canGoBack = await controller.canGoBack();
            final canGoForward = await controller.canGoForward();
            
            if (widget.isPrimary) {
              context.read<BrowserProvider>().updateCurrentTab(
                canGoBack: canGoBack,
                canGoForward: canGoForward,
              );
            }
          },
          
          // Handle popup windows - open in new tab
          onCreateWindow: (controller, createWindowAction) async {
            final url = createWindowAction.request.url?.toString();
            debugPrint('[WebView] Popup requested via onCreateWindow: $url');
            
            if (url != null && url.isNotEmpty && url != 'about:blank' && mounted) {
              try {
                // Open popup URL in a new tab
                final provider = context.read<BrowserProvider>();
                provider.createNewTab(url: url);
                debugPrint('[WebView] Successfully opened popup in new tab: $url');
              } catch (e) {
                debugPrint('[WebView] Error opening popup in new tab: $e');
              }
            } else {
              debugPrint('[WebView] Ignoring popup request: $url');
            }
            
            // Always return false to prevent default popup behavior (which can freeze)
            return false;
          },
        ),
        
        // Loading progress indicator
        if (_isLoading && _progress < 1.0)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              value: _progress,
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

  /// Get the WebView controller
  InAppWebViewController? get controller => _controller;

  /// Load a new URL
  Future<void> loadUrl(String url) async {
    if (_controller != null) {
      await _controller!.loadUrl(
        urlRequest: URLRequest(url: WebUri(url)),
      );
    }
  }

  /// Go back
  Future<void> goBack() async {
    if (_controller != null && await _controller!.canGoBack()) {
      await _controller!.goBack();
    }
  }

  /// Go forward
  Future<void> goForward() async {
    if (_controller != null && await _controller!.canGoForward()) {
      await _controller!.goForward();
    }
  }

  /// Reload
  Future<void> reload() async {
    await _controller?.reload();
  }

  /// Take screenshot
  Future<dynamic> takeScreenshot() async {
    return await _controller?.takeScreenshot();
  }
}
