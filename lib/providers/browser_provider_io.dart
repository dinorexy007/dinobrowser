/// Browser Provider IO helpers
/// 
/// Contains dart:io specific functionality for non-web platforms
library;

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Get the application documents directory path
Future<String> getAppDocsPath() async {
  final appDir = await getApplicationDocumentsDirectory();
  return appDir.path;
}

/// Create a directory
Future<void> createDirectory(String dirPath) async {
  await Directory(dirPath).create(recursive: true);
}

/// Write string to file
Future<void> writeStringToFile(String filePath, String content) async {
  await File(filePath).writeAsString(content);
}

/// Write bytes to file
Future<void> writeBytesToFile(String filePath, List<int> bytes) async {
  await File(filePath).writeAsBytes(bytes);
}

/// Join paths
String joinPath(String path1, String path2) {
  return path.join(path1, path2);
}
