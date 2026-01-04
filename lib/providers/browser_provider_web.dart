/// Browser Provider Web helpers
/// 
/// Web-compatible stubs for dart:io functionality
library;

/// Get the application documents directory path (stub for web)
Future<String> getAppDocsPath() async {
  // Web doesn't have a file system, return empty
  return '';
}

/// Create a directory (stub for web)
Future<void> createDirectory(String dirPath) async {
  // No-op on web
}

/// Write string to file (stub for web)
Future<void> writeStringToFile(String filePath, String content) async {
  // No-op on web - could use localStorage in future
}

/// Write bytes to file (stub for web)
Future<void> writeBytesToFile(String filePath, List<int> bytes) async {
  // No-op on web
}

/// Join paths (simple string concat for web)
String joinPath(String path1, String path2) {
  return '$path1/$path2';
}
