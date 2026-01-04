/// Raptor Mode Screen
/// 
/// Simple private browsing mode with DuckDuckGo search
/// Purple-themed stealth interface - no history, no cookies

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../models/tab_model.dart';
import 'package:uuid/uuid.dart';

class RaptorModeScreen extends StatefulWidget {
  const RaptorModeScreen({super.key});

  @override
  State<RaptorModeScreen> createState() => _RaptorModeScreenState();
}

class _RaptorModeScreenState extends State<RaptorModeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<TabModel> _raptorTabs = [];
  int _currentTabIndex = 0;
  
  @override
  void initState() {
    super.initState();
    // Create initial Raptor tab
    _createNewRaptorTab();
  }
  
  void _createNewRaptorTab() {
    final tab = TabModel(
      id: const Uuid().v4(),
      url: 'about:blank',
      title: 'New Raptor Tab',
    );
    setState(() {
      _raptorTabs.add(tab);
      _currentTabIndex = _raptorTabs.length - 1;
    });
  }
  
  void _closeRaptorTab(int index) {
    if (_raptorTabs.length <= 1) {
      // Don't close last tab
      return;
    }
    
    setState(() {
      _raptorTabs.removeAt(index);
      if (_currentTabIndex >= _raptorTabs.length) {
        _currentTabIndex = _raptorTabs.length - 1;
      }
    });
  }
  
  void _navigateToUrl(String input) {
    if (_raptorTabs.isEmpty) return;
    
    String url = input.trim();
    
    // Process input - use DuckDuckGo for search (no verification issues)
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      if (url.contains('.') && !url.contains(' ')) {
        url = 'https://$url';
      } else {
        // Use DuckDuckGo for privacy - no captchas or verification
        url = 'https://duckduckgo.com/?q=${Uri.encodeComponent(url)}';
      }
    }
    
    final controller = _raptorTabs[_currentTabIndex].controller;
    if (controller != null) {
      controller.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Exit Raptor Mode
        Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1A0A2E), // Deep purple background
        appBar: AppBar(
          backgroundColor: const Color(0xFF2D1B4E),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(
            children: [
              const Icon(Icons.shield, color: Color(0xFF9D4EDD), size: 24),
              const SizedBox(width: 8),
              const Text(
                'RAPTOR MODE',
                style: TextStyle(
                  color: Color(0xFF9D4EDD),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const Spacer(),
              // Private mode indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF9D4EDD).withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF9D4EDD)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.visibility_off, size: 12, color: Color(0xFF9D4EDD)),
                    SizedBox(width: 4),
                    Text(
                      'PRIVATE',
                      style: TextStyle(
                        color: Color(0xFF9D4EDD),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            // Tab bar
            Container(
              height: 48,
              color: const Color(0xFF2D1B4E),
              child: Row(
                children: [
                  // Tabs
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _raptorTabs.length,
                      itemBuilder: (context, index) {
                        final isActive = index == _currentTabIndex;
                        return GestureDetector(
                          onTap: () => setState(() => _currentTabIndex = index),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              color: isActive ? const Color(0xFF6A0DAD) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.public,
                                  size: 14,
                                  color: isActive ? Colors.white : const Color(0xFF9D4EDD),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _raptorTabs[index].displayTitle,
                                  style: TextStyle(
                                    color: isActive ? Colors.white : const Color(0xFF9D4EDD),
                                    fontSize: 12,
                                  ),
                                ),
                                if (isActive && _raptorTabs.length > 1)
                                  GestureDetector(
                                    onTap: () => _closeRaptorTab(index),
                                    child: const Padding(
                                      padding: EdgeInsets.only(left: 8),
                                      child: Icon(Icons.close, size: 14, color: Colors.white),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // New tab button
                  IconButton(
                    icon: const Icon(Icons.add, color: Color(0xFF9D4EDD)),
                    onPressed: _createNewRaptorTab,
                  ),
                ],
              ),
            ),
            
            // Search/URL bar
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2D1B4E),
                border: Border(
                  bottom: BorderSide(color: const Color(0xFF6A0DAD).withAlpha(50)),
                ),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search or enter URL...',
                  hintStyle: const TextStyle(color: Color(0xFF9D4EDD)),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF9D4EDD)),
                  filled: true,
                  fillColor: const Color(0xFF1A0A2E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: Color(0xFF6A0DAD)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: Color(0xFF6A0DAD)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: Color(0xFF9D4EDD), width: 2),
                  ),
                ),
                onSubmitted: (value) {
                  _navigateToUrl(value);
                  _searchController.clear();
                },
              ),
            ),
            
            // WebView
            Expanded(
              child: _raptorTabs.isEmpty
                  ? const Center(
                      child: Text(
                        'No tabs',
                        style: TextStyle(color: Color(0xFF9D4EDD)),
                      ),
                    )
                  : InAppWebView(
                      key: ValueKey(_raptorTabs[_currentTabIndex].id),
                      initialSettings: InAppWebViewSettings(
                        javaScriptEnabled: true,
                        javaScriptCanOpenWindowsAutomatically: true,
                        mediaPlaybackRequiresUserGesture: false,
                        allowsInlineMediaPlayback: true,
                        supportZoom: true,
                        builtInZoomControls: true,
                        displayZoomControls: false,
                        useHybridComposition: true,
                        cacheEnabled: false, // No cache in Raptor Mode
                        incognito: true, // Always incognito in Raptor Mode
                        mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                      ),
                      onWebViewCreated: (controller) {
                        _raptorTabs[_currentTabIndex].controller = controller;
                        if (_raptorTabs[_currentTabIndex].url != 'about:blank') {
                          controller.loadUrl(
                            urlRequest: URLRequest(
                              url: WebUri(_raptorTabs[_currentTabIndex].url),
                            ),
                          );
                        }
                      },
                      onLoadStart: (controller, url) {
                        setState(() {
                          if (url != null) {
                            _raptorTabs[_currentTabIndex].url = url.toString();
                            _raptorTabs[_currentTabIndex].isLoading = true;
                          }
                        });
                      },
                      onLoadStop: (controller, url) async {
                        final title = await controller.getTitle();
                        setState(() {
                          if (url != null) {
                            _raptorTabs[_currentTabIndex].url = url.toString();
                          }
                          _raptorTabs[_currentTabIndex].title = title ?? 'Raptor Tab';
                          _raptorTabs[_currentTabIndex].isLoading = false;
                          
                          // Update navigation state
                          controller.canGoBack().then((canGoBack) {
                            _raptorTabs[_currentTabIndex].canGoBack = canGoBack;
                          });
                          controller.canGoForward().then((canGoForward) {
                            _raptorTabs[_currentTabIndex].canGoForward = canGoForward;
                          });
                        });
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    // Clean up controllers
    for (final tab in _raptorTabs) {
      tab.controller?.dispose();
    }
    super.dispose();
  }
}
