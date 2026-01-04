/// Browser Screen
/// 
/// Main browser view with WebView, tabs, URL bar,
/// and split-screen (T-Rex Vision) functionality
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../config/theme.dart';
import '../providers/browser_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/webview_stack.dart';
import '../widgets/url_bar.dart';
import '../widgets/tab_bar_widget.dart';
import '../widgets/workspace_drawer.dart';
import '../widgets/dino_button.dart';
import '../widgets/home_screen.dart';
import '../services/bytez_service.dart';
import '../services/browser_tools.dart';
import '../services/grok_service.dart';

class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _showBottomNav = true;
  bool _isBookmarked = false;
  String? _pendingUrl;
  
  // Draggable AI button position
  Offset _aiButtonPosition = const Offset(16, 140); // right, bottom offsets - higher to avoid overlap with extension buttons

  @override
  void initState() {
    super.initState();
    _initializeBrowser();
  }

  Future<void> _initializeBrowser() async {
    final provider = context.read<BrowserProvider>();
    await provider.initialize();
    _checkBookmark();
  }

  Future<void> _checkBookmark() async {
    final provider = context.read<BrowserProvider>();
    final bookmarked = await provider.isCurrentPageBookmarked();
    if (mounted) {
      setState(() => _isBookmarked = bookmarked);
    }
  }

  void _navigateToUrl(String url) {
    if (url.isEmpty) return;
    
    final provider = context.read<BrowserProvider>();
    
    // Process the URL first (add https://, convert to search query, etc.)
    final processedUrl = _processUrl(url);
    
    // If WebView controller exists, always navigate directly via provider
    // This ensures search works from any page, not just home screen
    if (provider.currentTab?.controller != null) {
      // WebView exists - navigate directly using the controller
      provider.navigateTo(processedUrl);
    } else {
      // No WebView yet (on home screen) - create one with pending URL
      if (provider.currentTab != null) {
        provider.updateCurrentTab(url: processedUrl);
      }
      
      // Set pending URL to trigger WebView creation with this URL
      setState(() {
        _pendingUrl = processedUrl;
      });
    }
    
    _checkBookmark();
  }
  
  /// Process user input into a valid URL
  String _processUrl(String input) {
    input = input.trim();
    
    // Check if it's already a valid URL
    if (input.startsWith('http://') || input.startsWith('https://')) {
      return input;
    }
    
    // Check if it looks like a domain
    if (input.contains('.') && !input.contains(' ')) {
      return 'https://$input';
    }
    
    // Treat as a search query
    return 'https://www.google.com/search?q=${Uri.encodeComponent(input)}';
  }

  void _toggleBottomNav() {
    setState(() => _showBottomNav = !_showBottomNav);
  }

  @override
  Widget build(BuildContext context) {
    // Set system UI overlay style (not available on web)
    if (!kIsWeb) {
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: DinoColors.darkBg,
        systemNavigationBarIconBrightness: Brightness.light,
      ));
    }

    return Consumer2<BrowserProvider, AuthProvider>(
      builder: (context, provider, authProvider, child) {
        // Derive showHomeScreen from current tab state
        final currentTab = provider.currentTab;
        final bool showHomeScreen = (currentTab == null || currentTab.isBlank) && _pendingUrl == null;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            
            // Try to go back in WebView - goBack() will check controller directly
            final controller = provider.currentTab?.controller;
            if (controller != null) {
              final canGo = await controller.canGoBack();
              if (canGo) {
                await provider.goBack();
                return;
              }
            }
            // No history to go back, show exit confirmation
            _showExitConfirmationDialog();
          },
          child: Scaffold(
            key: _scaffoldKey,
            backgroundColor: DinoColors.darkBg,
            drawer: const WorkspaceDrawer(),
            body: SafeArea(
              child: Column(
                children: [
                  // Tab bar
                  const TabBarWidget(),
                  
                  // URL bar
                  UrlBar(
                    currentUrl: showHomeScreen ? '' : (provider.currentTab?.url ?? ''),
                    isLoading: provider.isLoading,
                    progress: provider.loadingProgress,
                    isBookmarked: _isBookmarked,
                    onSubmitted: (url) {
                      _navigateToUrl(url);
                    },
                    onReload: () => provider.reload(),
                    onStop: () => provider.stopLoading(),
                    onBookmark: () async {
                      await provider.addBookmark();
                      _checkBookmark();
                    },
                  ),
                  
                  // WebView area or Home Screen with floating AI button
                  Expanded(
                    child: Stack(
                      children: [
                        // Main content
                        showHomeScreen
                            ? HomeScreen(onNavigate: _navigateToUrl)
                            : kIsWeb
                                ? _buildWebFallback(provider)
                                : provider.isSplitScreen
                                    ? _buildSplitScreen(provider)
                                    : _buildSingleWebView(provider),
                        
                        // Floating Dino AI Summarize button (only when page is loaded)
                        if (!showHomeScreen && !kIsWeb && authProvider.isLoggedIn)
                          Positioned(
                            right: _aiButtonPosition.dx,
                            bottom: _aiButtonPosition.dy,
                            child: _buildDraggableAiButton(provider),
                          ),
                      ],
                    ),
                  ),
                  
                  // Bottom navigation
                  if (_showBottomNav)
                    FadeInUp(
                      duration: const Duration(milliseconds: 200),
                      child: _buildBottomNavigation(provider, authProvider),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Build single WebView
  Widget _buildSingleWebView(BrowserProvider provider) {
    // Use pending URL if available, otherwise use current tab URL or default
    final initialUrl = _pendingUrl ?? provider.currentTab?.url ?? 'https://www.google.com';
    final effectiveUrl = initialUrl.isEmpty || initialUrl == 'about:blank' ? 'https://www.google.com' : initialUrl;
    
    return WebViewStack(
      // IMPORTANT: Key should only use tab ID, NOT url hash!
      // Using url hash causes WebView to recreate on every navigation,
      // which destroys the controller and navigation history
      key: ValueKey('webview_${provider.currentTab?.id ?? 'main'}'),
      initialUrl: effectiveUrl,
      isPrimary: true,
      onControllerCreated: (controller) {
        // Clear pending URL after WebView is created - it's already loaded via initialUrl
        if (_pendingUrl != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _pendingUrl = null;
              });
            }
          });
        }
      },
      onPageFinished: (url, title) {
        _checkBookmark();
      },
    );
  }

  /// Build web platform fallback (browser-in-browser not supported)
  Widget _buildWebFallback(BrowserProvider provider) {
    final url = _pendingUrl ?? provider.currentTab?.url ?? '';
    
    return Container(
      decoration: const BoxDecoration(
        gradient: DinoGradients.darkGradient,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
                'Web preview mode - WebView features are limited.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: DinoColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (url.isNotEmpty)
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
                      url.length > 40 ? '${url.substring(0, 40)}...' : url,
                      style: const TextStyle(
                        color: DinoColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() => _pendingUrl = null);
              },
              icon: const Icon(Icons.home),
              label: const Text('Back to Home'),
              style: ElevatedButton.styleFrom(
                backgroundColor: DinoColors.cyberGreen,
                foregroundColor: DinoColors.deepJungle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build split-screen (T-Rex Vision) layout
  Widget _buildSplitScreen(BrowserProvider provider) {
    return Column(
      children: [
        // Primary WebView
        Expanded(
          flex: (provider.splitRatio * 100).toInt(),
          child: Container(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: DinoColors.cyberGreen,
                  width: 2,
                ),
              ),
            ),
            child: WebViewStack(
              key: ValueKey('${provider.currentTab?.id ?? 'main'}_primary'),
              initialUrl: provider.currentTab?.url ?? 'https://www.google.com',
              isPrimary: true,
            ),
          ),
        ),
        
        // Draggable divider
        GestureDetector(
          onVerticalDragUpdate: (details) {
            final screenHeight = MediaQuery.of(context).size.height;
            final delta = details.delta.dy / screenHeight;
            provider.updateSplitRatio(provider.splitRatio + delta);
          },
          child: Container(
            height: 20,
            color: DinoColors.surfaceBg,
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: DinoColors.cyberGreen,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
        
        // Secondary WebView
        Expanded(
          flex: ((1 - provider.splitRatio) * 100).toInt(),
          child: Stack(
            children: [
              WebViewStack(
                key: ValueKey('${provider.secondaryTab?.id ?? 'secondary'}_split'),
                initialUrl: provider.secondaryTab?.url ?? 'https://www.google.com',
                isPrimary: false,
                onControllerCreated: (controller) {
                  provider.setSecondaryController(controller);
                },
              ),
              
              // Secondary URL bar (compact)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DinoDimens.spacingMd,
                    vertical: 4,
                  ),
                  color: DinoColors.surfaceBg.withAlpha(230),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.public,
                        size: 16,
                        color: DinoColors.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          provider.secondaryTab?.domain ?? '',
                          style: const TextStyle(
                            color: DinoColors.textSecondary,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build bottom navigation bar
  Widget _buildBottomNavigation(BrowserProvider provider, AuthProvider authProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8, // Reduced from DinoDimens.spacingMd
        vertical: DinoDimens.spacingSm,
      ),
      decoration: BoxDecoration(
        color: DinoColors.surfaceBg,
        border: const Border(
          top: BorderSide(color: DinoColors.glassBorder, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Changed from spaceAround
        children: [
          // Menu/Workspaces button
          DinoIconButton(
            icon: Icons.menu,
            tooltip: 'Workspaces',
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          
          // Back button - always calls goBack which handles null checks internally
          DinoIconButton(
            icon: Icons.arrow_back_ios_new,
            tooltip: 'Back',
            isActive: provider.currentTab?.canGoBack ?? false,
            onPressed: (provider.currentTab?.canGoBack ?? false)
                ? () => provider.goBack()
                : null,
          ),
          
          // Forward button
          DinoIconButton(
            icon: Icons.arrow_forward_ios,
            tooltip: 'Forward',
            isActive: provider.currentTab?.canGoForward ?? false,
            onPressed: (provider.currentTab?.canGoForward ?? false)
                ? () => provider.goForward()
                : null,
          ),
          
          // Split screen toggle (T-Rex Vision)
          DinoIconButton(
            icon: provider.isSplitScreen
                ? Icons.splitscreen
                : Icons.splitscreen_outlined,
            tooltip: 'T-Rex Vision',
            isActive: provider.isSplitScreen,
            activeColor: DinoColors.raptorPurple,
            onPressed: () {
              if (provider.isSplitScreen) {
                _showMergeDialog(context, provider);
              } else {
                // If only one tab, just toggle (it will default to google or we can show selection)
                if (provider.tabs.length <= 1) {
                  provider.toggleSplitScreen();
                } else {
                  _showSplitSelectionDialog(context, provider);
                }
              }
            },
          ),
          
          // Fossil Mode (Save offline) - gated
          DinoIconButton(
            icon: Icons.downloading,
            tooltip: authProvider.isLoggedIn ? 'Fossil Mode' : 'Sign in to save pages',
            onPressed: () async {
              if (!authProvider.isLoggedIn) {
                _showAuthRequiredDialog('Fossil Mode');
                return;
              }
              
              final success = await provider.savePageOffline();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? '🦴 Page fossilized for offline reading!'
                          : 'Failed to save page',
                    ),
                    backgroundColor: success
                        ? DinoColors.cyberGreen.withAlpha(200)
                        : DinoColors.error,
                  ),
                );
              }
            },
          ),
          
          // Dino AI button - compact icon only
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [DinoColors.cyberGreen, Color(0xFF00D4AA)],
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: DinoColors.cyberGreen.withAlpha(60),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => Navigator.pushNamed(context, '/ai'),
                child: const Center(
                  child: Text('🦖', style: TextStyle(fontSize: 20)),
                ),
              ),
            ),
          ),
          
          // Tabs count / more options
          DinoIconButton(
            icon: Icons.layers_outlined,
            tooltip: '${provider.tabs.length} tabs',
            onPressed: () {
              // Show tabs overview or options
              _showTabsOverview(context, provider, authProvider);
            },
          ),
        ],
      ),
    );
  }

  void _showAuthRequiredDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DinoColors.surfaceBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: DinoColors.cyberGreen.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.lock, color: DinoColors.cyberGreen),
            ),
            const SizedBox(width: 12),
            const Text('Premium Feature'),
          ],
        ),
        content: Text(
          'Create an account to use $feature and other premium features.',
          style: const TextStyle(color: DinoColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later', style: TextStyle(color: DinoColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/auth');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: DinoColors.cyberGreen,
              foregroundColor: DinoColors.deepJungle,
            ),
            child: const Text('Create Account'),
          ),
        ],
      ),
    );
  }

  /// Show exit confirmation dialog
  void _showExitConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DinoColors.surfaceBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.exit_to_app, color: DinoColors.amberOrange, size: 20),
            SizedBox(width: 8),
            Flexible(child: Text('Exit Browser?', overflow: TextOverflow.ellipsis)),
          ],
        ),
        content: const Text(
          'Are you sure you want to exit?',
          style: TextStyle(color: DinoColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: DinoColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              SystemNavigator.pop(); // Exit app
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: DinoColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }

  /// Show tabs overview bottom sheet
  void _showTabsOverview(BuildContext context, BrowserProvider provider, AuthProvider authProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: DinoColors.surfaceBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DinoDimens.radiusLarge),
        ),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(DinoDimens.spacingMd),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Text(
                    '${provider.tabs.length} Tabs',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  // Add to Workspace button
                  if (authProvider.isLoggedIn && (provider.currentTab != null && !provider.currentTab!.isBlank))
                    Flexible(
                      child: IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _showAddToWorkspaceDialog(context, provider);
                        },
                        icon: const Icon(Icons.add_to_photos, size: 20),
                        tooltip: 'Add to Workspace',
                        color: DinoColors.cyberGreen,
                      ),
                    ),
                  Flexible(
                    child: IconButton(
                      onPressed: () {
                        provider.createNewTab();
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.add_circle_outline, size: 24),
                      tooltip: 'New Tab',
                      color: DinoColors.cyberGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DinoDimens.spacingMd),
              
              // Tabs grid
              SizedBox(
                height: 200,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.5,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: provider.tabs.length,
                  itemBuilder: (context, index) {
                    final tab = provider.tabs[index];
                    final isActive = index == provider.currentTabIndex;
                    
                    return GestureDetector(
                      onTap: () {
                        provider.switchToTab(index);
                        Navigator.pop(context);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: DinoColors.cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isActive
                                ? DinoColors.cyberGreen
                                : DinoColors.glassBorder,
                            width: isActive ? 2 : 1,
                          ),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.public,
                                  size: 14,
                                  color: DinoColors.textMuted,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    tab.displayTitle,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    provider.closeTab(index);
                                    if (provider.tabs.isEmpty) {
                                      Navigator.pop(context);
                                    }
                                  },
                                  child: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: DinoColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tab.domain,
                              style: const TextStyle(
                                fontSize: 10,
                                color: DinoColors.textMuted,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddToWorkspaceDialog(BuildContext context, BrowserProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DinoColors.surfaceBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.add_to_photos, color: DinoColors.cyberGreen),
            SizedBox(width: 12),
            Text('Add to Workspace'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Save "${provider.currentTab?.title ?? 'this page'}" to:',
              style: const TextStyle(color: DinoColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ...provider.workspaces.map((workspace) {
              final isCurrentWorkspace = workspace.id == provider.currentWorkspace.id;
              return ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: workspace.color.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(workspace.icon, color: workspace.color, size: 20),
                ),
                title: Text(workspace.name),
                trailing: isCurrentWorkspace
                    ? const Chip(
                        label: Text('Current', style: TextStyle(fontSize: 10)),
                        backgroundColor: DinoColors.cardBg,
                      )
                    : null,
                onTap: () async {
                  Navigator.pop(context);
                  await provider.addToWorkspaceModel(workspace);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('✅ Added to ${workspace.name}'),
                        backgroundColor: workspace.color.withAlpha(200),
                      ),
                    );
                  }
                },
              );
            }),
          ],
        ),
      ),
    );
  }
  void _showSplitSelectionDialog(BuildContext context, BrowserProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DinoColors.surfaceBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Select Tab for Split View'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: provider.tabs.length,
            itemBuilder: (ctx, index) {
              final tab = provider.tabs[index];
              if (tab.id == provider.currentTab?.id) return const SizedBox.shrink();
              
              return ListTile(
                leading: const Icon(Icons.public, color: DinoColors.textMuted),
                title: Text(tab.displayTitle),
                subtitle: Text(tab.domain, style: const TextStyle(fontSize: 10)),
                onTap: () {
                  Navigator.pop(ctx);
                  provider.toggleSplitScreen(secondary: tab);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.toggleSplitScreen(); // Defaults to google
            },
            child: const Text('New Google Tab'),
          ),
        ],
      ),
    );
  }

  void _showMergeDialog(BuildContext context, BrowserProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DinoColors.surfaceBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Keep which tab?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.looks_one, color: DinoColors.cyberGreen),
              title: Text(provider.currentTab?.displayTitle ?? 'Primary'),
              subtitle: const Text('Keep top/left tab'),
              onTap: () {
                Navigator.pop(ctx);
                provider.mergeSplitView(true);
              },
            ),
            if (provider.secondaryTab != null)
              ListTile(
                leading: const Icon(Icons.looks_two, color: DinoColors.raptorPurple),
                title: Text(provider.secondaryTab!.displayTitle),
                subtitle: const Text('Keep bottom/right tab'),
                onTap: () {
                  Navigator.pop(ctx);
                  provider.mergeSplitView(false);
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Build draggable Dino AI summarize button
  Widget _buildDraggableAiButton(BrowserProvider provider) {
    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          // Update position (using right/bottom offsets, so invert delta)
          _aiButtonPosition = Offset(
            (_aiButtonPosition.dx - details.delta.dx).clamp(8.0, MediaQuery.of(context).size.width - 72),
            (_aiButtonPosition.dy - details.delta.dy).clamp(8.0, MediaQuery.of(context).size.height - 200),
          );
        });
      },
      onTap: () => _showQuickSummarize(provider),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [DinoColors.cyberGreen, Color(0xFF00D4AA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: DinoColors.cyberGreen.withAlpha(100),
              blurRadius: 16,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: Text('🦖', style: TextStyle(fontSize: 28)),
        ),
      ),
    );
  }

  /// Show quick summarize bottom sheet
  Future<void> _showQuickSummarize(BrowserProvider provider) async {
    if (provider.currentTab?.controller == null) return;

    // Show loading bottom sheet
    showModalBottomSheet(
      context: context,
      backgroundColor: DinoColors.surfaceBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _SummarizeBottomSheet(provider: provider),
    );
  }
}

/// Bottom sheet for quick page summarization
class _SummarizeBottomSheet extends StatefulWidget {
  final BrowserProvider provider;

  const _SummarizeBottomSheet({required this.provider});

  @override
  State<_SummarizeBottomSheet> createState() => _SummarizeBottomSheetState();
}

class _SummarizeBottomSheetState extends State<_SummarizeBottomSheet> {
  bool _isLoading = true;
  String? _summary;
  String? _error;

  @override
  void initState() {
    super.initState();
    _summarizePage();
  }

  Future<void> _summarizePage() async {
    try {
      final controller = widget.provider.currentTab?.controller;
      if (controller == null) {
        setState(() {
          _error = 'No page loaded';
          _isLoading = false;
        });
        return;
      }

      final tools = BrowserTools(controller);
      final pageText = await tools.getPageText();
      final metadata = await tools.getPageMetadata();

      if (!pageText.success) {
        setState(() {
          _error = 'Could not read page content';
          _isLoading = false;
        });
        return;
      }

      // Use Groq API for fast, accurate page summarization
      final groq = GroqService();
      final response = await groq.summarizePage(
        pageTitle: metadata.title ?? 'Untitled',
        pageUrl: metadata.url ?? '',
        pageContent: pageText.data ?? '',
      );

      if (response.success && response.text != null) {
        setState(() {
          _summary = response.text;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response.error ?? 'Failed to summarize page';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [DinoColors.cyberGreen, Color(0xFF00D4AA)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text('🦖', style: TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Page Summary',
                  style: TextStyle(
                    color: DinoColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: DinoColors.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: DinoColors.glassBorder),
          const SizedBox(height: 16),
          
          // Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: DinoColors.cyberGreen),
                        SizedBox(height: 16),
                        Text(
                          'Summarizing page...',
                          style: TextStyle(color: DinoColors.textSecondary),
                        ),
                      ],
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, color: DinoColors.error, size: 48),
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              style: const TextStyle(color: DinoColors.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _isLoading = true;
                                  _error = null;
                                });
                                _summarizePage();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: DinoColors.cyberGreen,
                              ),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        child: MarkdownBody(
                          data: _summary ?? '',
                          selectable: true,
                          styleSheet: MarkdownStyleSheet(
                            h2: const TextStyle(
                              color: DinoColors.cyberGreen,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            p: const TextStyle(
                              color: DinoColors.textPrimary,
                              fontSize: 14,
                              height: 1.6,
                            ),
                            strong: const TextStyle(
                              color: DinoColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                            listBullet: const TextStyle(
                              color: DinoColors.cyberGreen,
                            ),
                          ),
                        ),
                      ),
          ),
          
          // Footer action
          if (!_isLoading && _summary != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _summary!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Summary copied to clipboard'),
                            backgroundColor: DinoColors.cyberGreen,
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copy'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: DinoColors.textSecondary,
                        side: const BorderSide(color: DinoColors.glassBorder),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/ai');
                      },
                      icon: const Icon(Icons.chat, size: 18),
                      label: const Text('Open Chat'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DinoColors.cyberGreen,
                        foregroundColor: DinoColors.deepJungle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}


