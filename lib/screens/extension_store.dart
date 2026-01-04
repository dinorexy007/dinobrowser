/// Extension Store Screen
/// 
/// Enhanced extension store supporting both Dino extensions and Chrome extensions
/// Features: Install from file, Chrome Web Store integration, extension management
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:file_picker/file_picker.dart';
import '../config/theme.dart';
import '../models/extension_model.dart';
import '../models/chrome_extension_model.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../services/extension_manager.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class ExtensionStoreScreen extends StatefulWidget {
  const ExtensionStoreScreen({super.key});
  @override
  State<ExtensionStoreScreen> createState() => _ExtensionStoreScreenState();
}

class _ExtensionStoreScreenState extends State<ExtensionStoreScreen> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  final DatabaseService _db = DatabaseService();
  final AuthService _authService = AuthService();
  final ExtensionManager _chromeExtManager = ExtensionManager();
  late TabController _tabController;
  
  // Simple Dino extensions
  List<ExtensionModel> _dinoExtensions = [];
  List<ExtensionModel> _cachedDinoExtensions = [];
  
  // Chrome extensions
  List<ChromeExtensionModel> _chromeExtensions = [];
  
  bool _isLoading = true;
  String? _error;
  String _selectedCategory = 'all';
  
  String get _currentUserId => _authService.currentUser?.uid ?? 'anonymous';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadExtensions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadExtensions() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      // Load Dino extensions
      final extensions = await _api.getExtensions();
      final cached = await _db.getCachedExtensions(userId: _currentUserId);
      
      // Load Chrome extensions
      await _chromeExtManager.initialize();
      
      if (mounted) {
        setState(() {
          _dinoExtensions = extensions;
          _cachedDinoExtensions = cached;
          _chromeExtensions = _chromeExtManager.extensions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _error = e.toString(); _isLoading = false; });
        final cached = await _db.getCachedExtensions(userId: _currentUserId);
        if (cached.isNotEmpty) setState(() { _dinoExtensions = cached; _cachedDinoExtensions = cached; });
      }
    }
  }

  List<ExtensionModel> get _filteredDinoExtensions => 
      _selectedCategory == 'all' ? _dinoExtensions : _dinoExtensions.where((e) => e.category == _selectedCategory).toList();

  Future<void> _toggleDinoExtension(ExtensionModel ext, bool enable) async {
    final isCached = _cachedDinoExtensions.any((e) => e.id == ext.id);
    if (!isCached && enable) {
      try {
        final withScript = await _api.getScript(ext.id);
        await _db.cacheExtension(withScript.copyWith(isEnabled: true), userId: _currentUserId);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: DinoColors.error));
        return;
      }
    } else {
      await _db.toggleExtension(ext.id, enable, userId: _currentUserId);
    }
    final cached = await _db.getCachedExtensions(userId: _currentUserId);
    setState(() => _cachedDinoExtensions = cached);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(enable ? '🦖 ${ext.name} activated!' : '${ext.name} disabled'), backgroundColor: enable ? DinoColors.cyberGreen.withAlpha(200) : DinoColors.surfaceBg));
  }

  bool _isDinoExtensionEnabled(int id) => _cachedDinoExtensions.any((e) => e.id == id && e.isEnabled);

  /// Clean up __MSG_*__ pattern names for display
  String _getDisplayName(String name) {
    // If it contains __MSG_ pattern, try to extract a readable name
    if (name.contains('__MSG_')) {
      // Extract the message key (e.g., "extName" from "__MSG_extName__")
      final match = RegExp(r'__MSG_(\w+)__').firstMatch(name);
      if (match != null) {
        final key = match.group(1)!;
        // Convert camelCase/snake_case to readable: extName -> Ext Name
        final readable = key
            .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
            .replaceAll('_', ' ')
            .replaceAll('ext ', '')
            .replaceAll('app ', '')
            .trim();
        // Capitalize first letter
        if (readable.isNotEmpty) {
          return readable[0].toUpperCase() + readable.substring(1);
        }
      }
      // Fallback: just remove the __MSG_ pattern
      return name.replaceAll(RegExp(r'__MSG_\w+__'), 'Extension').trim();
    }
    return name;
  }

  /// Clean up description for display
  String _getDisplayDescription(String? description) {
    if (description == null || description.isEmpty) return 'No description';
    if (description.contains('__MSG_')) {
      return description.replaceAll(RegExp(r'__MSG_\w+__'), '').trim();
    }
    return description;
  }


  Future<void> _installChromeExtensionFromFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final fileName = result.files.single.name.toLowerCase();
        
        if (!fileName.endsWith('.crx') && !fileName.endsWith('.zip')) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please select a .crx or .zip extension file'),
                backgroundColor: DinoColors.error,
              ),
            );
          }
          return;
        }

        // Show loading
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              backgroundColor: DinoColors.surfaceBg,
              content: const Row(
                children: [
                  CircularProgressIndicator(color: DinoColors.cyberGreen),
                  SizedBox(width: 16),
                  Text('Installing extension...', style: TextStyle(color: DinoColors.textPrimary)),
                ],
              ),
            ),
          );
        }

        final installResult = await _chromeExtManager.installFromFile(file);

        if (mounted) {
          Navigator.pop(context); // Close loading
          
          if (installResult.success) {
            setState(() {
              _chromeExtensions = _chromeExtManager.extensions;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ ${installResult.message}'),
                backgroundColor: DinoColors.cyberGreen,
              ),
            );
            // Switch to Chrome Extensions tab
            _tabController.animateTo(1);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('❌ ${installResult.message}'),
                backgroundColor: DinoColors.error,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: DinoColors.error),
        );
      }
    }
  }

  Future<void> _toggleChromeExtension(ChromeExtensionModel ext) async {
    final result = await _chromeExtManager.toggleExtension(ext.id);
    if (result.success && mounted) {
      setState(() {
        _chromeExtensions = _chromeExtManager.extensions;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ext.isEnabled ? '${ext.name} disabled' : '🦖 ${ext.name} activated!'),
          backgroundColor: !ext.isEnabled ? DinoColors.cyberGreen.withAlpha(200) : DinoColors.surfaceBg,
        ),
      );
    }
  }

  Future<void> _uninstallChromeExtension(ChromeExtensionModel ext) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DinoColors.surfaceBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Uninstall ${ext.name}?', style: const TextStyle(color: DinoColors.textPrimary)),
        content: const Text('This will remove the extension and all its data.', style: TextStyle(color: DinoColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Uninstall', style: TextStyle(color: DinoColors.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final result = await _chromeExtManager.uninstallExtension(ext.id);
      if (result.success && mounted) {
        setState(() {
          _chromeExtensions = _chromeExtManager.extensions;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? 'Uninstalled'), backgroundColor: DinoColors.surfaceBg),
        );
      }
    }
  }

  void _openExtensionPopup(ChromeExtensionModel ext) async {
    if (!ext.hasPopup || ext.action?.defaultPopup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This extension has no popup'), backgroundColor: DinoColors.error),
      );
      return;
    }
    
    // Clean up popup path - remove leading slash if present
    String popupRelPath = ext.action!.defaultPopup!;
    if (popupRelPath.startsWith('/')) {
      popupRelPath = popupRelPath.substring(1);
    }
    
    final popupPath = ext.getResourcePath(popupRelPath);
    final popupFile = File(popupPath);
    
    debugPrint('[Extension Popup] Extension: ${ext.name}');
    debugPrint('[Extension Popup] Local path: ${ext.localPath}');
    debugPrint('[Extension Popup] Popup relative: $popupRelPath');
    debugPrint('[Extension Popup] Full popup path: $popupPath');
    debugPrint('[Extension Popup] File exists: ${await popupFile.exists()}');
    
    // Check if file exists
    if (!await popupFile.exists()) {
      // Try to find popup.html in the extension directory
      final extDir = Directory(ext.localPath);
      String? foundPopup;
      
      if (await extDir.exists()) {
        await for (final entity in extDir.list(recursive: true)) {
          if (entity is File && entity.path.endsWith('popup.html')) {
            foundPopup = entity.path;
            break;
          }
        }
      }
      
      if (foundPopup != null) {
        debugPrint('[Extension Popup] Found popup at: $foundPopup');
        _showPopupWebView(ext, File(foundPopup));
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Popup file not found: $popupPath'),
              backgroundColor: DinoColors.error,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
      return;
    }
    
    _showPopupWebView(ext, popupFile);
  }
  
  void _showPopupWebView(ChromeExtensionModel ext, File popupFile) {
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: DinoColors.surfaceBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: DinoColors.surfaceBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: DinoColors.glassBorder)),
                ),
                child: Row(
                  children: [
                    // Extension icon
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: DinoColors.cardBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ext.bestIconPath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(ext.getResourcePath(ext.bestIconPath!)),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.extension, color: DinoColors.raptorPurple, size: 20),
                              ),
                            )
                          : const Icon(Icons.extension, color: DinoColors.raptorPurple, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _getDisplayName(ext.name),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: DinoColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: DinoColors.textMuted),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // WebView content
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                  child: InAppWebView(
                    initialUrlRequest: URLRequest(
                      url: WebUri(Uri.file(popupFile.path).toString()),
                    ),
                    initialSettings: InAppWebViewSettings(
                      javaScriptEnabled: true,
                      allowFileAccessFromFileURLs: true,
                      allowUniversalAccessFromFileURLs: true,
                      transparentBackground: false,
                      domStorageEnabled: true,
                      databaseEnabled: true,
                    ),
                    onLoadStop: (controller, url) async {
                      // Inject Chrome API polyfill
                      await _chromeExtManager.initialize();
                      try {
                        final polyfill = await DefaultAssetBundle.of(context).loadString('assets/js/chrome_api_polyfill.js');
                        await controller.evaluateJavascript(source: polyfill);
                      } catch (e) {
                        debugPrint('[Extension Popup] Failed to inject polyfill: $e');
                      }
                    },
                    onConsoleMessage: (controller, consoleMessage) {
                      debugPrint('[Extension Popup] ${consoleMessage.message}');
                    },
                    onLoadError: (controller, url, code, message) {
                      debugPrint('[Extension Popup] Load error: $code - $message for $url');
                    },
                  ),
                ),
              ),
            ],
          ),
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
        title: const Row(children: [
          Icon(Icons.extension, color: DinoColors.raptorPurple, size: 24),
          SizedBox(width: 8),
          Text('Extension Store'),
        ]),
        actions: [
          // Install from file button
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: DinoColors.cyberGreen),
            tooltip: 'Install from file',
            onPressed: _installChromeExtensionFromFile,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: DinoColors.cyberGreen,
          labelColor: DinoColors.cyberGreen,
          unselectedLabelColor: DinoColors.textMuted,
          labelPadding: const EdgeInsets.symmetric(horizontal: 8),
          tabs: [
            const Tab(text: 'Dino'),
            Tab(text: _chromeExtensions.isEmpty ? 'Chrome' : 'Chrome (${_chromeExtensions.length})'),
            const Tab(text: 'Installed'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDinoStoreTab(),
          _buildChromeExtensionsTab(),
          _buildInstalledTab(),
        ],
      ),
    );
  }

  Widget _buildDinoStoreTab() {
    return Column(children: [
      SizedBox(height: 50, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), children: [
        for (final cat in [{'id': 'all', 'name': 'All'}, {'id': 'productivity', 'name': 'Productivity'}, {'id': 'privacy', 'name': 'Privacy'}, {'id': 'appearance', 'name': 'Appearance'}])
          Padding(padding: const EdgeInsets.only(right: 8), child: FilterChip(selected: _selectedCategory == cat['id'], label: Text(cat['name']!), onSelected: (_) => setState(() => _selectedCategory = cat['id']!), backgroundColor: DinoColors.cardBg, selectedColor: DinoColors.cyberGreen)),
      ])),
      Expanded(child: _isLoading ? const Center(child: CircularProgressIndicator(color: DinoColors.cyberGreen)) : _buildDinoList(_filteredDinoExtensions)),
    ]);
  }

  Widget _buildChromeExtensionsTab() {
    if (_chromeExtensions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.extension, size: 80, color: DinoColors.textMuted.withAlpha(100)),
              const SizedBox(height: 24),
              const Text(
                'No Chrome Extensions',
                style: TextStyle(color: DinoColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Install Chrome extensions from .crx or .zip files',
                style: TextStyle(color: DinoColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _installChromeExtensionFromFile,
                icon: const Icon(Icons.add),
                label: const Text('Install Extension'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DinoColors.cyberGreen,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '💡 Tip: Download extensions from\nchrome.google.com/webstore',
                style: TextStyle(color: DinoColors.textMuted, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadExtensions,
      color: DinoColors.cyberGreen,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _chromeExtensions.length,
        itemBuilder: (ctx, i) {
          final ext = _chromeExtensions[i];
          return FadeInUp(
            duration: Duration(milliseconds: 200 + i * 50),
            child: _buildChromeExtensionCard(ext),
          );
        },
      ),
    );
  }

  Widget _buildChromeExtensionCard(ChromeExtensionModel ext) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DinoColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ext.isEnabled ? DinoColors.cyberGreen.withAlpha(100) : DinoColors.glassBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Icon
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: DinoColors.surfaceBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ext.bestIconPath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(ext.getResourcePath(ext.bestIconPath!)),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.extension, color: DinoColors.raptorPurple),
                        ),
                      )
                    : const Icon(Icons.extension, color: DinoColors.raptorPurple),
              ),
              const SizedBox(width: 12),
              // Name and version
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getDisplayName(ext.name),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: DinoColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'v${ext.version} • MV${ext.manifestVersion}',
                      style: const TextStyle(color: DinoColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              // Toggle switch
              Switch(
                value: ext.isEnabled,
                onChanged: (_) => _toggleChromeExtension(ext),
                activeColor: DinoColors.cyberGreen,
              ),
            ],
          ),
          if (ext.description != null || ext.name.contains('__MSG_')) ...[
            const SizedBox(height: 12),
            Text(
              _getDisplayDescription(ext.description),
              style: const TextStyle(color: DinoColors.textSecondary, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),
          // Info badges
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (ext.hasContentScripts)
                _buildBadge('Content Scripts', Icons.code, DinoColors.cyberGreen),
              if (ext.hasPopup)
                _buildBadge('Popup', Icons.open_in_new, DinoColors.raptorPurple),
              if (ext.hasBackground)
                _buildBadge('Background', Icons.settings, Colors.orange),
            ],
          ),
          const SizedBox(height: 12),
          // Action buttons row
          Row(
            children: [
              // Open Popup button (for extensions with popup)
              if (ext.hasPopup && ext.isEnabled)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openExtensionPopup(ext),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Open'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DinoColors.cyberGreen,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              if (ext.hasPopup && ext.isEnabled)
                const SizedBox(width: 12),
              // Uninstall button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _uninstallChromeExtension(ext),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Uninstall'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: DinoColors.error,
                    side: const BorderSide(color: DinoColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildInstalledTab() {
    final installedDino = _cachedDinoExtensions.where((e) => e.isEnabled).toList();
    final installedChrome = _chromeExtensions.where((e) => e.isEnabled).toList();

    if (installedDino.isEmpty && installedChrome.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.extension_off, size: 80, color: DinoColors.textMuted.withAlpha(100)),
            const SizedBox(height: 16),
            const Text('No Extensions Installed', style: TextStyle(color: DinoColors.textMuted)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (installedChrome.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('Chrome Extensions', style: TextStyle(color: DinoColors.textMuted, fontWeight: FontWeight.bold)),
          ),
          ...installedChrome.map((ext) => FadeInUp(child: _buildChromeExtensionCard(ext))),
          const SizedBox(height: 16),
        ],
        if (installedDino.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('Dino Extensions', style: TextStyle(color: DinoColors.textMuted, fontWeight: FontWeight.bold)),
          ),
          ...installedDino.asMap().entries.map((entry) {
            final i = entry.key;
            final ext = entry.value;
            return FadeInUp(
              duration: Duration(milliseconds: 200 + i * 50),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: DinoColors.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _isDinoExtensionEnabled(ext.id) ? DinoColors.cyberGreen.withAlpha(100) : DinoColors.glassBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(color: DinoColors.surfaceBg, borderRadius: BorderRadius.circular(12)),
                      child: Center(child: Text(ext.categoryIcon, style: const TextStyle(fontSize: 24))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ext.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                          const SizedBox(height: 4),
                          Text(ext.description, style: const TextStyle(color: DinoColors.textSecondary, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    Switch(value: _isDinoExtensionEnabled(ext.id), onChanged: (v) => _toggleDinoExtension(ext, v), activeColor: DinoColors.cyberGreen),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  ListView _buildDinoList(List<ExtensionModel> exts) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: exts.length,
      itemBuilder: (ctx, i) {
        final ext = exts[i];
        return FadeInUp(
          duration: Duration(milliseconds: 200 + i * 50),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DinoColors.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _isDinoExtensionEnabled(ext.id) ? DinoColors.cyberGreen.withAlpha(100) : DinoColors.glassBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(color: DinoColors.surfaceBg, borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text(ext.categoryIcon, style: const TextStyle(fontSize: 24))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ext.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text(ext.description, style: const TextStyle(color: DinoColors.textSecondary, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Switch(value: _isDinoExtensionEnabled(ext.id), onChanged: (v) => _toggleDinoExtension(ext, v), activeColor: DinoColors.cyberGreen),
              ],
            ),
          ),
        );
      },
    );
  }
}
