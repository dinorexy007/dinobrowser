/// Groq AI Service
/// 
/// High-performance LLM inference using Groq API
/// Used for page summarization and chat responses
library;

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Groq API configuration
const String _groqBaseUrl = 'https://api.groq.com/openai/v1/chat/completions';
const String _groqApiKey = String.fromEnvironment('GROQ_API_KEY');
const Duration _timeout = Duration(seconds: 60);

/// Groq model options
enum GroqModel {
  llama70b('llama-3.3-70b-versatile', 'Llama 3.3 70B'),
  llama8b('llama-3.1-8b-instant', 'Llama 3.1 8B (Fast)'),
  mixtral('mixtral-8x7b-32768', 'Mixtral 8x7B');

  final String modelId;
  final String displayName;
  
  const GroqModel(this.modelId, this.displayName);
}

/// Response from Groq API
class GroqResponse {
  final bool success;
  final String? text;
  final String? error;

  GroqResponse({
    required this.success,
    this.text,
    this.error,
  });

  factory GroqResponse.success(String text) {
    return GroqResponse(success: true, text: text);
  }

  factory GroqResponse.failure(String error) {
    return GroqResponse(success: false, error: error);
  }
}

/// Groq AI Service - Fast inference for LLMs
class GroqService {
  static final GroqService _instance = GroqService._internal();
  factory GroqService() => _instance;
  GroqService._internal();

  final http.Client _client = http.Client();

  /// Send a chat completion request to Groq
  Future<GroqResponse> chat({
    required String message,
    String? systemPrompt,
    GroqModel model = GroqModel.llama70b,
    double temperature = 0.7,
    int maxTokens = 2048,
  }) async {
    try {
      final messages = <Map<String, String>>[];

      // Add system prompt if provided
      if (systemPrompt != null && systemPrompt.isNotEmpty) {
        messages.add({
          'role': 'system',
          'content': systemPrompt,
        });
      }

      // Add user message
      messages.add({
        'role': 'user',
        'content': message,
      });

      final response = await _client.post(
        Uri.parse(_groqBaseUrl),
        headers: {
          'Authorization': 'Bearer $_groqApiKey',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'model': model.modelId,
          'messages': messages,
          'temperature': temperature,
          'max_tokens': maxTokens,
        }),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Extract text from OpenAI-compatible response format
        final choices = data['choices'] as List?;
        if (choices != null && choices.isNotEmpty) {
          final content = choices[0]['message']?['content']?.toString();
          if (content != null && content.isNotEmpty) {
            return GroqResponse.success(content);
          }
        }
        
        return GroqResponse.failure('Empty response from Groq');
      } else if (response.statusCode == 401) {
        return GroqResponse.failure('Invalid Groq API key');
      } else if (response.statusCode == 429) {
        return GroqResponse.failure('Rate limit exceeded - try again later');
      } else {
        // Try to extract error message
        try {
          final errorData = json.decode(response.body);
          final errorMsg = errorData['error']?['message']?.toString() ?? 
                          'Server error: ${response.statusCode}';
          return GroqResponse.failure(errorMsg);
        } catch (e) {
          return GroqResponse.failure('Server error: ${response.statusCode}');
        }
      }
    } on SocketException {
      return GroqResponse.failure('Network error - check your connection');
    } on TimeoutException {
      return GroqResponse.failure('Request timed out - try again');
    } catch (e) {
      return GroqResponse.failure('Error: $e');
    }
  }

  /// Summarize page content
  Future<GroqResponse> summarizePage({
    required String pageTitle,
    required String pageUrl,
    required String pageContent,
  }) async {
    final systemPrompt = '''You are a helpful AI assistant for a web browser called Dino Browser. 
Your task is to provide concise, accurate summaries of web pages.
Format your response using markdown with clear sections.''';

    final message = '''Please summarize this webpage:

**Title:** $pageTitle
**URL:** $pageUrl

**Content:**
$pageContent

Provide a summary in this format:
## Summary
A brief 2-3 sentence overview of what this page is about.

## Key Points
- Point 1
- Point 2
- Point 3
(Add more points as needed for longer content)''';

    return chat(
      message: message,
      systemPrompt: systemPrompt,
      model: GroqModel.llama70b,
      temperature: 0.3, // Lower temperature for factual summarization
      maxTokens: 1024,
    );
  }

  /// General chat response (for AI chat screen)
  Future<GroqResponse> generateResponse({
    required String prompt,
    String? pageContext,
  }) async {
    final systemPrompt = '''You are Dino AI, a helpful browser assistant for Dino Browser.
Format responses with markdown: use **bold**, bullet points, and ## headings.
Be concise but comprehensive.''';

    String fullMessage = prompt;
    if (pageContext != null && pageContext.isNotEmpty) {
      fullMessage = '''$prompt

---
**Page Context:**
$pageContext''';
    }

    return chat(
      message: fullMessage,
      systemPrompt: systemPrompt,
      model: GroqModel.llama70b,
      temperature: 0.7,
      maxTokens: 2048,
    );
  }

  /// Check if Groq API is available
  Future<bool> isAvailable() async {
    try {
      final response = await chat(
        message: 'Hello',
        maxTokens: 10,
      );
      return response.success;
    } catch (e) {
      return false;
    }
  }

  /// Clean up resources
  void dispose() {
    _client.close();
  }
}

/// Custom timeout exception for type checking
class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
}
