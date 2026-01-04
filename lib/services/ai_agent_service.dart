/// AI Agent Service
/// 
/// Handles communication with the Dino Browser AI Agent API
/// Provides reasoning and decision-making capabilities
library;

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// AI Agent API endpoint
const String _aiAgentUrl = 'https://bilalcode.site/ai-agent.php';

/// API Key for authentication
const String _apiKey = 'DINOBROWSER_2025';

/// Timeout for API requests
const Duration _timeout = Duration(seconds: 30);

/// Message model for chat history
class AiMessage {
  final int? id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;
  final bool isLoading;

  AiMessage({
    this.id,
    required this.content,
    required this.isUser,
    DateTime? timestamp,
    this.isError = false,
    this.isLoading = false,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create a loading indicator message
  factory AiMessage.loading() {
    return AiMessage(
      content: '',
      isUser: false,
      isLoading: true,
    );
  }

  /// Create an error message
  factory AiMessage.error(String message) {
    return AiMessage(
      content: message,
      isUser: false,
      isError: true,
    );
  }
}

/// AI Agent Service for Dino Browser
class AiAgentService {
  static final AiAgentService _instance = AiAgentService._internal();
  factory AiAgentService() => _instance;
  AiAgentService._internal();

  final http.Client _client = http.Client();

  /// Send a message to the AI agent
  /// 
  /// [message] - User's natural language instruction
  /// [pageContext] - Optional page content for context
  /// 
  /// Returns the agent's response text
  Future<String> sendMessage(String message, {String? pageContext}) async {
    try {
      // Build the full message with context if provided
      String fullMessage = message;
      if (pageContext != null && pageContext.isNotEmpty) {
        fullMessage = '$message\n\n--- Page Content ---\n$pageContext';
      }

      final response = await _client.post(
        Uri.parse(_aiAgentUrl),
        headers: {
          'Content-Type': 'application/json',
          'X-API-KEY': _apiKey,
        },
        body: json.encode({
          'message': fullMessage,
        }),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Check for error in response
        if (data['error'] != null) {
          throw AiAgentException(data['error']);
        }
        
        // Get reply from response
        final reply = data['reply'] ?? data['response'] ?? '';
        if (reply.isEmpty) {
          throw AiAgentException('Empty response from AI agent');
        }
        
        return reply;
      } else if (response.statusCode == 403) {
        throw AiAgentException('Invalid API credentials');
      } else {
        throw AiAgentException('Server error: ${response.statusCode}');
      }
    } on SocketException {
      throw AiAgentException('AI temporarily unavailable');
    } on FormatException {
      throw AiAgentException('Invalid response from AI');
    } catch (e) {
      if (e is AiAgentException) rethrow;
      throw AiAgentException('Failed to connect to AI: $e');
    }
  }

  /// Quick action: Summarize page content
  Future<String> summarizePage(String pageContent) async {
    return sendMessage(
      'Please summarize the following webpage content concisely:',
      pageContext: pageContent,
    );
  }

  /// Quick action: Explain selected text
  Future<String> explainText(String selectedText) async {
    return sendMessage(
      'Please explain the following text in simple terms:\n\n"$selectedText"',
    );
  }

  /// Quick action: Analyze content
  Future<String> analyzeContent(String content) async {
    return sendMessage(
      'Please analyze the following content and provide key insights:',
      pageContext: content,
    );
  }

  /// Check if the AI agent is reachable
  Future<bool> isAvailable() async {
    try {
      final response = await _client.post(
        Uri.parse(_aiAgentUrl),
        headers: {
          'Content-Type': 'application/json',
          'X-API-KEY': _apiKey,
        },
        body: json.encode({'message': 'ping'}),
      ).timeout(const Duration(seconds: 5));
      
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

/// Custom exception for AI Agent errors
class AiAgentException implements Exception {
  final String message;
  
  AiAgentException(this.message);
  
  @override
  String toString() => message;
}
