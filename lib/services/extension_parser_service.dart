/// Extension Parser Service
/// 
/// Parses Chrome extension packages (CRX and ZIP files)
/// Extracts contents and reads manifest.json
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/chrome_extension_model.dart';

/// CRX file header versions
enum CrxVersion { crx2, crx3, unknown }

/// Result of parsing an extension
class ExtensionParseResult {
  final bool success;
  final ChromeExtensionModel? extension;
  final String? errorMessage;

  ExtensionParseResult.success(this.extension)
      : success = true,
        errorMessage = null;

  ExtensionParseResult.failure(this.errorMessage)
      : success = false,
        extension = null;
}

/// Extension Parser Service
class ExtensionParserService {
  static final ExtensionParserService _instance = ExtensionParserService._internal();
  factory ExtensionParserService() => _instance;
  ExtensionParserService._internal();

  /// Base directory for storing extensions
  Future<String> get _extensionsDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final extDir = Directory(path.join(appDir.path, 'extensions'));
    if (!await extDir.exists()) {
      await extDir.create(recursive: true);
    }
    return extDir.path;
  }

  /// Parse a CRX or ZIP file and extract extension
  Future<ExtensionParseResult> parseExtensionFile(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final fileName = path.basename(file.path).toLowerCase();

      if (fileName.endsWith('.crx')) {
        return await _parseCrxFile(bytes);
      } else if (fileName.endsWith('.zip')) {
        return await _parseZipFile(bytes);
      } else {
        // Try to detect format from bytes
        if (_isCrxFile(bytes)) {
          return await _parseCrxFile(bytes);
        } else {
          return await _parseZipFile(bytes);
        }
      }
    } catch (e) {
      return ExtensionParseResult.failure('Failed to parse extension: $e');
    }
  }

  /// Parse extension from URL (download first)
  Future<ExtensionParseResult> parseExtensionFromUrl(String url) async {
    try {
      final httpClient = HttpClient();
      final request = await httpClient.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode != 200) {
        return ExtensionParseResult.failure('Failed to download: HTTP ${response.statusCode}');
      }

      final bytes = await response.fold<List<int>>(
        [],
        (previous, element) => previous..addAll(element),
      );

      httpClient.close();

      final uint8Bytes = Uint8List.fromList(bytes);

      if (_isCrxFile(uint8Bytes)) {
        return await _parseCrxFile(uint8Bytes);
      } else {
        return await _parseZipFile(uint8Bytes);
      }
    } catch (e) {
      return ExtensionParseResult.failure('Failed to download extension: $e');
    }
  }

  /// Check if bytes represent a CRX file
  bool _isCrxFile(Uint8List bytes) {
    if (bytes.length < 4) return false;
    // CRX magic number: "Cr24"
    return bytes[0] == 0x43 && bytes[1] == 0x72 && 
           bytes[2] == 0x32 && bytes[3] == 0x34;
  }

  /// Detect CRX version
  CrxVersion _getCrxVersion(Uint8List bytes) {
    if (bytes.length < 8) return CrxVersion.unknown;
    
    // Version is at bytes 4-7 (little-endian uint32)
    final version = bytes[4] | (bytes[5] << 8) | (bytes[6] << 16) | (bytes[7] << 24);
    
    if (version == 2) return CrxVersion.crx2;
    if (version == 3) return CrxVersion.crx3;
    return CrxVersion.unknown;
  }

  /// Parse CRX file format
  Future<ExtensionParseResult> _parseCrxFile(Uint8List bytes) async {
    try {
      final version = _getCrxVersion(bytes);
      int zipOffset;

      if (version == CrxVersion.crx2) {
        // CRX2: header = magic(4) + version(4) + pubKeyLen(4) + sigLen(4)
        if (bytes.length < 16) {
          return ExtensionParseResult.failure('Invalid CRX2 file');
        }
        final pubKeyLen = bytes[8] | (bytes[9] << 8) | (bytes[10] << 16) | (bytes[11] << 24);
        final sigLen = bytes[12] | (bytes[13] << 8) | (bytes[14] << 16) | (bytes[15] << 24);
        zipOffset = 16 + pubKeyLen + sigLen;
      } else if (version == CrxVersion.crx3) {
        // CRX3: header = magic(4) + version(4) + headerLen(4) + header
        if (bytes.length < 12) {
          return ExtensionParseResult.failure('Invalid CRX3 file');
        }
        final headerLen = bytes[8] | (bytes[9] << 8) | (bytes[10] << 16) | (bytes[11] << 24);
        zipOffset = 12 + headerLen;
      } else {
        return ExtensionParseResult.failure('Unknown CRX version');
      }

      if (zipOffset >= bytes.length) {
        return ExtensionParseResult.failure('Invalid CRX file structure');
      }

      // Extract ZIP portion
      final zipBytes = bytes.sublist(zipOffset);
      return await _parseZipFile(Uint8List.fromList(zipBytes));
    } catch (e) {
      return ExtensionParseResult.failure('Failed to parse CRX: $e');
    }
  }

  /// Parse ZIP file containing extension
  Future<ExtensionParseResult> _parseZipFile(Uint8List bytes) async {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      
      // Find manifest.json
      ArchiveFile? manifestFile;
      for (final file in archive) {
        if (file.name == 'manifest.json' || file.name.endsWith('/manifest.json')) {
          // Prefer root manifest
          if (file.name == 'manifest.json') {
            manifestFile = file;
            break;
          }
          manifestFile ??= file;
        }
      }

      if (manifestFile == null) {
        return ExtensionParseResult.failure('No manifest.json found in extension');
      }

      // Parse manifest
      final manifestContent = utf8.decode(manifestFile.content as List<int>);
      final manifest = jsonDecode(manifestContent) as Map<String, dynamic>;

      // Validate manifest
      if (manifest['name'] == null) {
        return ExtensionParseResult.failure('Invalid manifest: missing name');
      }
      if (manifest['manifest_version'] == null) {
        return ExtensionParseResult.failure('Invalid manifest: missing manifest_version');
      }

      // Generate extension ID
      final extId = ChromeExtensionModel.generateExtensionId(manifest['name']);

      // Create extraction directory
      final baseDir = await _extensionsDir;
      final extDir = Directory(path.join(baseDir, extId));
      
      // Clean up if exists
      if (await extDir.exists()) {
        await extDir.delete(recursive: true);
      }
      await extDir.create(recursive: true);

      // Extract all files (skip directories)
      for (final file in archive) {
        // Skip directories - they end with / or have no content
        final isDirectory = file.name.endsWith('/') || 
                            file.name.endsWith('\\') ||
                            !file.isFile ||
                            (file.size == 0 && file.content.isEmpty);
        
        if (!isDirectory && file.name.isNotEmpty) {
          try {
            final outputPath = path.join(extDir.path, file.name);
            final outputFile = File(outputPath);
            await outputFile.parent.create(recursive: true);
            await outputFile.writeAsBytes(file.content as List<int>);
          } catch (e) {
            // Skip files that can't be extracted (might be directories)
            print('[ExtensionParser] Skipping: ${file.name} - $e');
          }
        }
      }

      // Load i18n messages to resolve __MSG_*__ placeholders
      final resolvedName = await _resolveI18nMessage(manifest['name'] ?? 'Unknown Extension', extDir.path);
      final resolvedDesc = await _resolveI18nMessage(manifest['description'] ?? '', extDir.path);
      
      // Update manifest with resolved values for model creation
      final resolvedManifest = Map<String, dynamic>.from(manifest);
      resolvedManifest['name'] = resolvedName;
      resolvedManifest['description'] = resolvedDesc;

      // Create extension model with resolved i18n values
      final extension = ChromeExtensionModel.fromManifest(
        resolvedManifest,
        extDir.path,
        overrideId: extId,
      );

      // Load content scripts
      await _loadExtensionContent(extension);

      return ExtensionParseResult.success(extension);
    } catch (e) {
      return ExtensionParseResult.failure('Failed to parse ZIP: $e');
    }
  }

  /// Resolve Chrome i18n message placeholders like __MSG_extName__
  Future<String> _resolveI18nMessage(String text, String extPath) async {
    if (!text.contains('__MSG_')) return text;
    
    // Try to load messages from various locales
    final locales = ['en', 'en_US', 'en_GB'];
    Map<String, dynamic>? messages;
    
    for (final locale in locales) {
      final messagesFile = File(path.join(extPath, '_locales', locale, 'messages.json'));
      if (await messagesFile.exists()) {
        try {
          final content = await messagesFile.readAsString();
          messages = jsonDecode(content) as Map<String, dynamic>;
          break;
        } catch (e) {
          // Try next locale
        }
      }
    }
    
    if (messages == null) {
      // Try any available locale
      final localesDir = Directory(path.join(extPath, '_locales'));
      if (await localesDir.exists()) {
        try {
          final subdirs = await localesDir.list().toList();
          for (final subdir in subdirs) {
            if (subdir is Directory) {
              final messagesFile = File(path.join(subdir.path, 'messages.json'));
              if (await messagesFile.exists()) {
                final content = await messagesFile.readAsString();
                messages = jsonDecode(content) as Map<String, dynamic>;
                break;
              }
            }
          }
        } catch (e) {
          // Ignore
        }
      }
    }
    
    if (messages == null) {
      // No messages found, strip the __MSG_ pattern
      return text.replaceAll(RegExp(r'__MSG_\w+__'), 'Extension');
    }
    
    // Replace all __MSG_xxx__ with the actual message
    String resolved = text;
    final msgPattern = RegExp(r'__MSG_(\w+)__');
    for (final match in msgPattern.allMatches(text)) {
      final msgName = match.group(1)!;
      final msgData = messages[msgName] ?? messages[msgName.toLowerCase()];
      if (msgData != null && msgData is Map && msgData['message'] != null) {
        resolved = resolved.replaceAll('__MSG_${msgName}__', msgData['message']);
      }
    }
    
    return resolved;
  }

  /// Load content scripts and CSS into memory
  Future<void> _loadExtensionContent(ChromeExtensionModel extension) async {
    for (final contentScript in extension.contentScripts) {
      // Load JS files
      for (final jsPath in contentScript.js) {
        final file = File(extension.getResourcePath(jsPath));
        if (await file.exists()) {
          extension.loadedScripts[jsPath] = await file.readAsString();
        }
      }

      // Load CSS files
      for (final cssPath in contentScript.css) {
        final file = File(extension.getResourcePath(cssPath));
        if (await file.exists()) {
          extension.loadedStyles[cssPath] = await file.readAsString();
        }
      }
    }
  }

  /// Delete an extension from storage
  Future<bool> deleteExtension(String extensionId) async {
    try {
      final baseDir = await _extensionsDir;
      final extDir = Directory(path.join(baseDir, extensionId));
      if (await extDir.exists()) {
        await extDir.delete(recursive: true);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// List all installed extension directories
  Future<List<String>> listInstalledExtensionIds() async {
    try {
      final baseDir = await _extensionsDir;
      final dir = Directory(baseDir);
      if (!await dir.exists()) return [];

      final subdirs = await dir.list().where((e) => e is Directory).toList();
      return subdirs.map((d) => path.basename(d.path)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Reload an extension from disk
  Future<ExtensionParseResult> reloadExtension(String extensionId) async {
    try {
      final baseDir = await _extensionsDir;
      final extDir = Directory(path.join(baseDir, extensionId));
      
      if (!await extDir.exists()) {
        return ExtensionParseResult.failure('Extension not found');
      }

      final manifestFile = File(path.join(extDir.path, 'manifest.json'));
      if (!await manifestFile.exists()) {
        return ExtensionParseResult.failure('Manifest not found');
      }

      final manifestContent = await manifestFile.readAsString();
      final manifest = jsonDecode(manifestContent) as Map<String, dynamic>;

      // Resolve i18n messages
      final resolvedName = await _resolveI18nMessage(manifest['name'] ?? 'Unknown Extension', extDir.path);
      final resolvedDesc = await _resolveI18nMessage(manifest['description'] ?? '', extDir.path);
      
      final resolvedManifest = Map<String, dynamic>.from(manifest);
      resolvedManifest['name'] = resolvedName;
      resolvedManifest['description'] = resolvedDesc;

      final extension = ChromeExtensionModel.fromManifest(
        resolvedManifest,
        extDir.path,
        overrideId: extensionId,
      );

      await _loadExtensionContent(extension);

      return ExtensionParseResult.success(extension);
    } catch (e) {
      return ExtensionParseResult.failure('Failed to reload: $e');
    }
  }
}
