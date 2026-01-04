/// Browser Provider
/// 
/// Central state management for Dino Browser
/// Handles tabs, navigation, workspaces, and split-screen state
/// All user data operations are now isolated by user ID
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:uuid/uuid.dart';
import '../models/tab_model.dart';
import '../models/workspace_model.dart';
import '../models/history_model.dart';
import '../services/database_service.dart';
import '../services/history_manager.dart';
import '../services/script_injector.dart';
import '../services/session_manager.dart';
import '../services/proxy_service.dart';
import '../services/auth_service.dart';
import '../services/firestore_sync_service.dart';
import '../services/device_id_service.dart';

// Conditional imports for non-web platforms
import 'browser_provider_io.dart' if (dart.library.html) 'browser_provider_web.dart' as platform_io;

class BrowserProvider extends ChangeNotifier {
  // ==================== CORE STATE ====================
  
  /// Map of workspace ID to list of tabs
  final Map<String, List<TabModel>> _workspaceTabs = {};
  
  /// Map of workspace ID to current tab index
  final Map<String, int> _workspaceCurrentIndices = {};
  
  /// Get tabs for the current workspace
  List<TabModel> get tabs {
    return List.unmodifiable(_workspaceTabs[_currentWorkspace.id] ?? []);
  }
  
  /// Currently active tab index in the current workspace
  int get currentTabIndex => _workspaceCurrentIndices[_currentWorkspace.id] ?? 0;
  
  /// Get current active tab
  TabModel? get currentTab {
    final workspaceTabs = _workspaceTabs[_currentWorkspace.id] ?? [];
    final index = _workspaceCurrentIndices[_currentWorkspace.id] ?? 0;
    return workspaceTabs.isNotEmpty && index < workspaceTabs.length 
        ? workspaceTabs[index] 
        : null;
  }
  
  // ==================== SPLIT SCREEN (T-Rex Vision) ====================
  
  /// Whether split-screen mode is active
  bool _isSplitScreen = false;
  bool get isSplitScreen => _isSplitScreen;
  
  /// Split screen ratio (0.0 - 1.0, where 0.5 is equal split)
  double _splitRatio = 0.5;
  double get splitRatio => _splitRatio;
  
  /// Secondary tab for split screen
  TabModel? _secondaryTab;
  TabModel? get secondaryTab => _secondaryTab;
  
  // ==================== WORKSPACE ====================
  
  /// Current active workspace
  WorkspaceModel _currentWorkspace = DefaultWorkspaces.defaultWorkspace;
  WorkspaceModel get currentWorkspace => _currentWorkspace;
  
  /// Available workspaces
  List<WorkspaceModel> _workspaces = DefaultWorkspaces.all;
  List<WorkspaceModel> get workspaces => List.unmodifiable(_workspaces);
  
  // ==================== SERVICES ====================
  
  final DatabaseService _db = DatabaseService();
  final HistoryManager _historyManager = HistoryManager();
  final ScriptInjector _scriptInjector = ScriptInjector();
  final SessionManager _sessionManager = SessionManager();
  final ProxyService _proxyService = ProxyService();
  final AuthService _authService = AuthService();
  final FirestoreSyncService _syncService = FirestoreSyncService();
  final DeviceIdService _deviceIdService = DeviceIdService();
  
  /// Cached device ID for guest users
  String _deviceId = 'anonymous';
  
  ScriptInjector get scriptInjector => _scriptInjector;
  ProxyService get proxyService => _proxyService;
  
  /// Get current user ID for data isolation
  /// Returns device-specific ID if no user is logged in
  String get _currentUserId => _authService.currentUser?.uid ?? _deviceId;
  
  /// Get the current user ID (public access for other providers)
  String get currentUserId => _currentUserId;
  
  /// Set device ID from DeviceIdService
  Future<void> initializeDeviceId() async {
    _deviceId = await _deviceIdService.getDeviceId();
  }
  
  // ==================== RAPTOR MODE (PRIVATE BROWSING + PROXY) ====================
  
  /// Is Raptor Mode (incognito + proxy bypass) enabled
  bool _raptorModeEnabled = false;
  bool get raptorModeEnabled => _raptorModeEnabled;
  
  /// Is proxy currently active and working
  bool _proxyActive = false;
  bool get proxyActive => _proxyActive;
  
  // ==================== UI STATE ====================
  
  /// Whether URL bar is focused
  bool _isUrlBarFocused = false;
  bool get isUrlBarFocused => _isUrlBarFocused;
  
  /// Search suggestions
  List<String> _searchSuggestions = [];
  List<String> get searchSuggestions => _searchSuggestions;
  
  /// Page loading progress (0.0 - 1.0)
  double _loadingProgress = 0.0;
  double get loadingProgress => _loadingProgress;
  
  /// Is any tab currently loading?
  bool get isLoading => currentTab?.isLoading ?? false;
  
  // ==================== INITIALIZATION ====================
  
  /// Initialize the browser provider
  Future<void> initialize() async {
    // Initialize device ID for guest user isolation
    await initializeDeviceId();
    
    await _historyManager.initialize();
    await _scriptInjector.initialize();
    
    // Try to restore previous session for current user
    final sessionData = await _sessionManager.restoreSession(userId: _currentUserId);
    if (sessionData != null) {
      await _restoreSessionData(sessionData);
    } else {
      // Initialize all workspaces with at least one tab
      for (final workspace in _workspaces) {
        if (!_workspaceTabs.containsKey(workspace.id) || _workspaceTabs[workspace.id]!.isEmpty) {
          final tab = TabModel(
            id: const Uuid().v4(),
            url: 'about:blank',
            title: 'New Tab',
          );
          _workspaceTabs[workspace.id] = [tab];
          _workspaceCurrentIndices[workspace.id] = 0;
        }
      }
    }
  }
  
  /// Restore session data from saved state
  Future<void> _restoreSessionData(Map<String, dynamic> sessionData) async {
    try {
      // Restore workspace tabs
      final workspacesData = sessionData['workspaces'] as Map<String, dynamic>?;
      if (workspacesData != null) {
        workspacesData.forEach((workspaceId, data) {
          final tabsData = data['tabs'] as List<dynamic>?;
          final currentIndex = data['currentIndex'] as int? ?? 0;
          
          if (tabsData != null && tabsData.isNotEmpty) {
            final tabs = tabsData.map((tabData) {
              return TabModel(
                id: tabData['id'] as String? ?? const Uuid().v4(),
                url: tabData['url'] as String? ?? 'about:blank',
                title: tabData['title'] as String? ?? 'New Tab',
              );
            }).toList();
            
            _workspaceTabs[workspaceId] = tabs;
            _workspaceCurrentIndices[workspaceId] = currentIndex.clamp(0, tabs.length - 1);
          }
        });
      }
      
      // Ensure all workspaces have at least one tab
      for (final workspace in _workspaces) {
        if (!_workspaceTabs.containsKey(workspace.id) || _workspaceTabs[workspace.id]!.isEmpty) {
          final tab = TabModel(
            id: const Uuid().v4(),
            url: 'about:blank',
            title: 'New Tab',
          );
          _workspaceTabs[workspace.id] = [tab];
          _workspaceCurrentIndices[workspace.id] = 0;
        }
      }
      
      // Restore current workspace
      final currentWorkspaceId = sessionData['currentWorkspace'] as String?;
      if (currentWorkspaceId != null) {
        final workspace = _workspaces.firstWhere(
          (w) => w.id == currentWorkspaceId,
          orElse: () => DefaultWorkspaces.defaultWorkspace,
        );
        _currentWorkspace = workspace;
      }
    } catch (e) {
      // If restoration fails, just use default initialization
      for (final workspace in _workspaces) {
        if (!_workspaceTabs.containsKey(workspace.id) || _workspaceTabs[workspace.id]!.isEmpty) {
          final tab = TabModel(
            id: const Uuid().v4(),
            url: 'about:blank',
            title: 'New Tab',
          );
          _workspaceTabs[workspace.id] = [tab];
          _workspaceCurrentIndices[workspace.id] = 0;
        }
      }
    }
  }
  
  /// Save current session state
  Future<void> saveSession() async {
    final sessionData = <String, dynamic>{
      'currentWorkspace': _currentWorkspace.id,
      'workspaces': {},
    };
    
    // Save each workspace's tabs
    _workspaceTabs.forEach((workspaceId, tabs) {
      sessionData['workspaces'][workspaceId] = {
        'currentIndex': _workspaceCurrentIndices[workspaceId] ?? 0,
        'tabs': tabs.map((tab) => {
          'id': tab.id,
          'url': tab.url,
          'title': tab.title,
        }).toList(),
      };
    });
    
    await _sessionManager.saveSession(sessionData, userId: _currentUserId);
  }
  
  // ==================== TAB MANAGEMENT ====================
  
  /// Create a new tab in the current workspace
  Future<TabModel> createNewTab({String? url}) async {
    final tab = TabModel(
      id: const Uuid().v4(),
      url: url ?? 'about:blank',
      title: url != null ? _extractDomain(url) : 'New Tab',
    );
    
    final workspaceId = _currentWorkspace.id;
    _workspaceTabs[workspaceId] ??= [];
    _workspaceTabs[workspaceId]!.add(tab);
    _workspaceCurrentIndices[workspaceId] = _workspaceTabs[workspaceId]!.length - 1;
    
    notifyListeners();
    return tab;
  }
  
  /// Close a tab by index in the current workspace
  Future<void> closeTab(int index) async {
    final workspaceId = _currentWorkspace.id;
    final workspaceTabs = _workspaceTabs[workspaceId] ?? [];
    
    if (index < 0 || index >= workspaceTabs.length) return;
    
    if (workspaceTabs.length <= 1) {
      // Last tab - reset to home screen instead of closing
      final tab = workspaceTabs.first;
      tab.url = 'about:blank';
      tab.title = 'New Tab';
      tab.isLoading = false;
      tab.canGoBack = false;
      tab.canGoForward = false;
      // Clear the WebView to show home screen
      tab.controller?.loadUrl(urlRequest: URLRequest(url: WebUri('about:blank')));
      notifyListeners();
      return;
    }
    
    workspaceTabs.removeAt(index);
    
    // Adjust current tab index
    int currentIndex = _workspaceCurrentIndices[workspaceId] ?? 0;
    if (currentIndex >= workspaceTabs.length) {
      _workspaceCurrentIndices[workspaceId] = workspaceTabs.length - 1;
    } else if (currentIndex > index) {
      _workspaceCurrentIndices[workspaceId] = currentIndex - 1;
    }
    
    notifyListeners();
  }
  
  /// Switch to a specific tab in the current workspace
  void switchToTab(int index) {
    final workspaceId = _currentWorkspace.id;
    final workspaceTabs = _workspaceTabs[workspaceId] ?? [];
    
    if (index < 0 || index >= workspaceTabs.length) return;
    if (_workspaceCurrentIndices[workspaceId] == index) return;
    
    _workspaceCurrentIndices[workspaceId] = index;
    notifyListeners();
  }
  
  /// Update current tab with new values
  void updateCurrentTab({
    String? url,
    String? title,
    String? faviconUrl,
    bool? isLoading,
    double? progress,
    bool? canGoBack,
    bool? canGoForward,
    InAppWebViewController? controller,
  }) {
    final tab = currentTab;
    if (tab == null) return;
    
    if (url != null) tab.url = url;
    if (title != null) tab.title = title;
    if (faviconUrl != null) tab.faviconUrl = faviconUrl;
    if (isLoading != null) tab.isLoading = isLoading;
    if (progress != null) {
      tab.progress = progress;
      _loadingProgress = progress;
    }
    if (canGoBack != null) {
      tab.canGoBack = canGoBack;
      debugPrint('[BrowserProvider] Updated canGoBack: $canGoBack for tab: ${tab.title}');
    }
    if (canGoForward != null) {
      tab.canGoForward = canGoForward;
      debugPrint('[BrowserProvider] Updated canGoForward: $canGoForward for tab: ${tab.title}');
    }
    if (controller != null) {
      tab.controller = controller;
      debugPrint('[BrowserProvider] Controller stored for tab: ${tab.id}');
    }
    
    tab.lastAccessedAt = DateTime.now();
    
    notifyListeners();
  }
  
  // ==================== NAVIGATION ====================
  
  /// Navigate to a URL in the current tab
  /// Works even if controller is null - WebView will load the URL when created
  Future<void> navigateTo(String input) async {
    if (input.isEmpty) return;
    
    final url = _processInput(input);
    final tab = currentTab;
    
    if (tab == null) {
      // No current tab, create one
      await createNewTab(url: url);
      return;
    }
    
    // Always update the tab URL
    tab.url = url;
    tab.title = _extractDomain(url);
    notifyListeners();
    
    // If controller is ready, load immediately
    if (tab.controller != null) {
      await tab.controller!.loadUrl(
        urlRequest: URLRequest(url: WebUri(url)),
      );
    }
    // If controller is null, the WebView will load this URL when it's created
  }
  
  /// Go back in the current tab
  Future<void> goBack() async {
    final controller = currentTab?.controller;
    if (controller != null && await controller.canGoBack()) {
      await controller.goBack();
    }
  }
  
  /// Go forward in the current tab
  Future<void> goForward() async {
    final controller = currentTab?.controller;
    if (controller != null && await controller.canGoForward()) {
      await controller.goForward();
    }
  }
  
  /// Reload the current tab
  Future<void> reload() async {
    if (currentTab?.controller != null) {
      await currentTab!.controller!.reload();
    }
  }
  
  /// Stop loading the current tab
  Future<void> stopLoading() async {
    if (currentTab?.controller != null) {
      await currentTab!.controller!.stopLoading();
    }
  }
  
  /// Process user input into a valid URL
  String _processInput(String input) {
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
  
  // ==================== SPLIT SCREEN ====================
  
  /// Toggle split-screen mode
  void toggleSplitScreen({TabModel? secondary}) {
    _isSplitScreen = !_isSplitScreen;
    
    if (_isSplitScreen) {
      if (secondary != null) {
        _secondaryTab = secondary;
      } else if (_secondaryTab == null) {
        // Find another tab in the same workspace if available
        final otherTabs = tabs.where((t) => t.id != currentTab?.id).toList();
        if (otherTabs.isNotEmpty) {
          _secondaryTab = otherTabs.first;
        } else {
          // Default to google if no other tabs
          _secondaryTab = TabModel(
            id: const Uuid().v4(),
            url: 'https://www.google.com',
            title: 'Google',
          );
        }
      }
    } else {
      // Leaving split screen, the caller might want to choose which one to keep
      // If we are here via a simple toggle, we keep the primary
    }
    
    notifyListeners();
  }

  /// Merge split view by selecting which tab to keep as primary
  void mergeSplitView(bool keepPrimary) {
    if (!_isSplitScreen) return;
    
    if (!keepPrimary && _secondaryTab != null) {
      // Find index of secondary tab if it belongs to current workspace
      final workspaceId = _currentWorkspace.id;
      final workspaceTabs = _workspaceTabs[workspaceId] ?? [];
      final index = workspaceTabs.indexWhere((t) => t.id == _secondaryTab!.id);
      
      if (index != -1) {
        _workspaceCurrentIndices[workspaceId] = index;
      } else {
        // If secondary tab wasn't in workspace (e.g. temporary Google tab), 
        // add it if it's not blank
        if (!_secondaryTab!.isBlank) {
          workspaceTabs.add(_secondaryTab!);
          _workspaceCurrentIndices[workspaceId] = workspaceTabs.length - 1;
        }
      }
    }
    
    _isSplitScreen = false;
    _secondaryTab = null;
    notifyListeners();
  }
  
  /// Update split screen ratio
  void updateSplitRatio(double ratio) {
    _splitRatio = ratio.clamp(0.2, 0.8);
    notifyListeners();
  }
  
  /// Navigate in the secondary (split) tab
  Future<void> navigateSecondary(String input) async {
    if (_secondaryTab?.controller == null) return;
    
    final url = _processInput(input);
    await _secondaryTab!.controller!.loadUrl(
      urlRequest: URLRequest(url: WebUri(url)),
    );
  }
  
  /// Update secondary tab controller
  void setSecondaryController(InAppWebViewController controller) {
    if (_secondaryTab != null) {
      _secondaryTab!.controller = controller;
      notifyListeners();
    }
  }
  
  // ==================== WORKSPACE ====================
  
  /// Switch to a different workspace
  Future<void> switchWorkspace(WorkspaceModel workspace) async {
    if (_currentWorkspace.id == workspace.id) return;
    _currentWorkspace = workspace;
    
    // Load saved workspace pages if workspace has no open tabs
    if (!_workspaceTabs.containsKey(workspace.id) || _workspaceTabs[workspace.id]!.isEmpty) {
      // Try to load saved pages from database  
      final savedPages = await _db.getWorkspacePages(workspace.id, userId: _currentUserId);
      
      if (savedPages.isNotEmpty) {
        // Create tabs from saved pages
        final tabs = savedPages.map((page) {
          return TabModel(
            id: const Uuid().v4(),
            url: page['url'] as String? ?? 'about:blank',
            title: page['title'] as String? ?? 'Saved Page',
          );
        }).toList();
        _workspaceTabs[workspace.id] = tabs;
        _workspaceCurrentIndices[workspace.id] = 0;
      } else {
        // No saved pages, create blank tab
        final tab = TabModel(
          id: const Uuid().v4(),
          url: 'about:blank',
          title: 'New Tab',
        );
        _workspaceTabs[workspace.id] = [tab];
        _workspaceCurrentIndices[workspace.id] = 0;
      }
    }
    
    notifyListeners();
  }
  
  // ==================== HISTORY ====================
  
  /// Record current page to history
  Future<HistoryModel?> recordHistory() async {
    if (currentTab?.controller == null || currentTab?.url == null) return null;
    
    return await _historyManager.recordVisit(
      controller: currentTab!.controller!,
      url: currentTab!.url,
      title: currentTab!.title,
      userId: _currentUserId,
      workspaceId: _currentWorkspace.id,
      faviconUrl: currentTab!.faviconUrl,
    );
  }
  
  /// Get grouped history for Time-Travel view
  /// Shows all history regardless of workspace
  Future<Map<String, List<HistoryModel>>> getGroupedHistory() async {
    return await _historyManager.getGroupedHistory(userId: _currentUserId);
  }
  
  // ==================== FOSSIL MODE (Offline Save) ====================
  
  /// Save current page for offline reading
Future<bool> savePageOffline() async {
  // Fossil mode not supported on web platform
  if (kIsWeb) return false;
  
  // CRITICAL: Capture tab reference at the START to prevent race conditions
  // This ensures we save the correct tab even if user switches tabs during async ops
  final tab = currentTab;
  if (tab?.controller == null) return false;
  
  // Capture URL and title immediately before any async operations
  final tabUrl = tab!.url;
  final tabTitle = tab.title;
  final controller = tab.controller!;
  
  try {
    // Get page HTML from the captured controller
    final html = await controller.getHtml();
    if (html == null) return false;
    
    // Generate filename
    final appPath = await platform_io.getAppDocsPath();
    final savedPagesDir = platform_io.joinPath(appPath, 'saved_pages');
    await platform_io.createDirectory(savedPagesDir);
    
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final htmlPath = platform_io.joinPath(savedPagesDir, 'page_$timestamp.html');
    
    // Save HTML
    await platform_io.writeStringToFile(htmlPath, html);
    
    // Take screenshot from the captured controller
    String? screenshotPath;
    try {
      final screenshot = await controller.takeScreenshot(
        screenshotConfiguration: ScreenshotConfiguration(
          compressFormat: CompressFormat.JPEG,
          quality: 70,
        ),
      );
      if (screenshot != null) {
        screenshotPath = platform_io.joinPath(savedPagesDir, 'ss_$timestamp.jpg');
        await platform_io.writeBytesToFile(screenshotPath, screenshot);
      }
    } catch (e) {
      // Screenshot failed, continue without it
    }
    
    // Save to database with userId using captured tab data
    await _db.savePage(
      userId: _currentUserId,
      url: tabUrl,
      title: tabTitle,
      htmlPath: htmlPath,
      screenshotPath: screenshotPath,
    );
    
    return true;
  } catch (e) {
    return false;
  }
}
  
  /// Get saved pages
  Future<List<Map<String, dynamic>>> getSavedPages() async {
    return await _db.getSavedPages(userId: _currentUserId);
  }
  // ==================== BOOKMARKS ====================
  
  /// Add current page to bookmarks
  Future<bool> addBookmark() async {
    if (currentTab == null || currentTab!.url.isEmpty) return false;
    
    await _db.addBookmark(
      userId: _currentUserId,
      url: currentTab!.url,
      title: currentTab!.title,
      faviconUrl: currentTab!.faviconUrl,
      workspaceId: _currentWorkspace.id,
    );
    
    // Sync to cloud (fire and forget)
    _syncService.syncBookmark(
      url: currentTab!.url,
      title: currentTab!.title,
      faviconUrl: currentTab!.faviconUrl,
      workspaceId: _currentWorkspace.id,
    ).catchError((_) {});
    
    return true;
  }
  
  /// Check if current page is bookmarked
  Future<bool> isCurrentPageBookmarked() async {
    if (currentTab == null) return false;
    return await _db.isBookmarked(
      currentTab!.url,
      userId: _currentUserId,
      workspaceId: _currentWorkspace.id,
    );
  }
  
  /// Get bookmarks for current workspace
  Future<List<Map<String, dynamic>>> getBookmarks() async {
    return await _db.getBookmarks(userId: _currentUserId, workspaceId: _currentWorkspace.id);
  }

  /// Get bookmarks for a specific workspace (by ID)
  Future<List<Map<String, dynamic>>> getWorkspaceBookmarks(String workspaceId) async {
    return await _db.getBookmarks(userId: _currentUserId, workspaceId: workspaceId);
  }
  
  /// Delete a bookmark by ID
  Future<void> deleteBookmark(int id, {String? url}) async {
    await _db.deleteBookmark(id, userId: _currentUserId);
    
    // Sync deletion to cloud if URL provided
    if (url != null) {
      _syncService.deleteBookmarkFromCloud(url).catchError((_) {});
    }
  }
  
  /// Add current page to a specific workspace (saves to workspace_pages, not bookmarks)
  Future<bool> addToWorkspace(String workspaceId, String? url, String? title) async {
    if (url == null || url.isEmpty) return false;
    
    await _db.addWorkspacePage(
      userId: _currentUserId,
      url: url,
      title: title ?? 'Untitled',
      workspaceId: workspaceId,
    );
    
    return true;
  }
  
  /// Add current page to a specific workspace model
  Future<bool> addToWorkspaceModel(WorkspaceModel workspace) async {
    return addToWorkspace(workspace.id, currentTab?.url, currentTab?.title);
  }
  
  /// Get saved pages for a workspace
  Future<List<Map<String, dynamic>>> getWorkspaceSavedPages(String workspaceId) async {
    return await _db.getWorkspacePages(workspaceId, userId: _currentUserId);
  }
  
  // ==================== SPEED DIAL (ROAR) ====================
  
  /// Get speed dial sites
  Future<List<Map<String, dynamic>>> getSpeedDial() async {
    return await _db.getSpeedDial(userId: _currentUserId);
  }
  
  // ==================== URL BAR STATE ====================
  
  /// Set URL bar focus state
  void setUrlBarFocused(bool focused) {
    _isUrlBarFocused = focused;
    if (!focused) {
      _searchSuggestions = [];
    }
    notifyListeners();
  }
  
  /// Extract domain from URL
  String _extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.replaceFirst('www.', '');
    } catch (e) {
      return url;
    }
  }
  
  // ==================== RAPTOR MODE ====================
  
  /// Toggle Raptor Mode (private browsing with proxy bypass)
  /// Now navigates to separate Raptor Mode screen
  Future<void> toggleRaptorMode() async {
    _raptorModeEnabled = !_raptorModeEnabled;
    
    if (_raptorModeEnabled) {
      // Initialize proxy service when entering Raptor Mode
      await _proxyService.initialize();
      if (_proxyService.hasProxies) {
        _proxyActive = true;
      } else {
        // Try to fetch proxies
        await _proxyService.fetchProxies();
        _proxyActive = _proxyService.hasProxies;
      }
    } else {
      // Exit Raptor Mode
      _proxyActive = false;
    }
    
    notifyListeners();
  }
  
  /// Manually toggle proxy (within or outside Raptor Mode)
  Future<void> toggleProxy() async {
    if (!_proxyService.hasProxies) {
      await _proxyService.fetchProxies();
    }
    
    _proxyActive = !_proxyActive && _proxyService.hasProxies;
    notifyListeners();
  }
  
  /// Rotate to next proxy
  void rotateProxy() {
    _proxyService.rotateProxy();
    notifyListeners();
  }
  
  /// Get current proxy info
  String? get currentProxyInfo {
    if (!_proxyActive) return null;
    final proxy = _proxyService.currentProxy;
    if (proxy == null) return null;
    return '${proxy.country ?? 'Unknown'} - ${proxy.address}';
  }
  
  /// Clear user session on logout
  /// Closes all tabs, resets to default workspace, clears split screen
  Future<void> clearUserSession() async {
    // Close all tab controllers
    _workspaceTabs.forEach((_, tabs) {
      for (final tab in tabs) {
        tab.controller?.dispose();
      }
    });
    
    // Clear all workspace tabs
    _workspaceTabs.clear();
    _workspaceCurrentIndices.clear();
    
    // Reset to default workspace
    _currentWorkspace = DefaultWorkspaces.defaultWorkspace;
    _workspaces = DefaultWorkspaces.all;
    
    // Clear split screen
    _isSplitScreen = false;
    _secondaryTab?.controller?.dispose();
    _secondaryTab = null;
    _splitRatio = 0.5;
    
    // Clear Raptor Mode
    _raptorModeEnabled = false;
    _proxyActive = false;
    
    // Reset loading state
    _loadingProgress = 0.0;
    _isUrlBarFocused = false;
    _searchSuggestions = [];
    
    // Create fresh home tab in default workspace
    final freshTab = TabModel(
      id: const Uuid().v4(),
      url: 'about:blank',
      title: 'New Tab',
    );
    _workspaceTabs[_currentWorkspace.id] = [freshTab];
    _workspaceCurrentIndices[_currentWorkspace.id] = 0;
    
    // Clear saved session for the old user
    await _sessionManager.clearSession(userId: _deviceId);
    
    notifyListeners();
  }
  
  /// Reinitialize browser for new user after login
  /// Clears old session and starts fresh with user's cloud data
  Future<void> reinitializeForNewUser() async {
    // Clear the guest session completely
    await clearUserSession();
    
    // Reinitialize with new user context
    await initialize();
  }
  
  @override
  void dispose() {
    // Clean up all controllers in all workspaces
    _workspaceTabs.forEach((_, tabs) {
      for (final tab in tabs) {
        tab.controller?.dispose();
      }
    });
    _secondaryTab?.controller?.dispose();
    super.dispose();
  }
}
