/// API Service
/// 
/// Handles HTTP calls to bilalcode.site backend
/// Fetches extensions and scripts for injection
library;

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/extension_model.dart';

/// Base URL for the Dino Browser API
const String _baseUrl = 'https://bilalcode.site/api';

/// Timeout duration for API requests
const Duration _timeout = Duration(seconds: 10);

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final http.Client _client = http.Client();

  /// Fetch all available extensions from the server
  /// 
  /// [category] - Optional filter by category (productivity, privacy, etc.)
  /// [limit] - Optional limit on number of results
  /// 
  /// Returns list of ExtensionModel objects
  Future<List<ExtensionModel>> getExtensions({
    String? category,
    int? limit,
  }) async {
    try {
      // Build URL with query parameters
      final queryParams = <String, String>{};
      if (category != null) queryParams['category'] = category;
      if (limit != null) queryParams['limit'] = limit.toString();

      final uri = Uri.parse('$_baseUrl/get_extensions.php').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final response = await _client.get(uri).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true && data['extensions'] != null) {
          return (data['extensions'] as List)
              .map((e) => ExtensionModel.fromJson(e))
              .toList();
        }
        
        throw ApiException('Invalid response format');
      }
      
      throw ApiException('Server error: ${response.statusCode}');
    } on SocketException {
      throw ApiException('No internet connection');
    } on FormatException {
      throw ApiException('Invalid response format');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to fetch extensions: $e');
    }
  }

  /// Fetch JavaScript code for a specific extension
  /// 
  /// [extensionId] - ID of the extension to fetch
  /// 
  /// Returns ExtensionModel with js_code populated
  Future<ExtensionModel> getScript(int extensionId) async {
    try {
      final uri = Uri.parse('$_baseUrl/get_script.php').replace(
        queryParameters: {'id': extensionId.toString()},
      );

      final response = await _client.get(uri).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true && data['extension'] != null) {
          return ExtensionModel.fromJson(data['extension']);
        }
        
        throw ApiException('Extension not found');
      }

      if (response.statusCode == 404) {
        throw ApiException('Extension not found');
      }
      
      throw ApiException('Server error: ${response.statusCode}');
    } on SocketException {
      throw ApiException('No internet connection');
    } on FormatException {
      throw ApiException('Invalid response format');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to fetch script: $e');
    }
  }

  /// Check if the API server is reachable
  Future<bool> isServerReachable() async {
    try {
      final uri = Uri.parse('$_baseUrl/get_extensions.php?limit=1');
      final response = await _client.get(uri).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Clean up resources
  void dispose() {
    _client.close();
  }
}

/// Custom exception for API errors
class ApiException implements Exception {
  final String message;
  
  ApiException(this.message);
  
  @override
  String toString() => 'ApiException: $message';
}
