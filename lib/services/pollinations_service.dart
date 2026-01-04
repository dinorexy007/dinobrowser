/// Pollinations AI Service - Free AI Generation
/// 
/// Uses Pollinations.ai free API for:
/// - Text-to-Image generation
/// - Text generation with modern LLMs (DeepSeek, Mistral, OpenAI)
/// 
/// No API key required for basic usage - completely free and open
/// 
/// APIs:
/// - Image: https://image.pollinations.ai/prompt/{prompt}
/// - Text: https://text.pollinations.ai/{prompt}
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Pollinations API configuration
const String _pollinationsImageUrl = 'https://image.pollinations.ai/prompt';
// Using OpenAI-compatible endpoint for better reliability and model access
const String _pollinationsTextUrl = 'https://text.pollinations.ai/openai/v1/chat/completions';
const Duration _imageTimeout = Duration(seconds: 120); // Image generation can be slow
const Duration _textTimeout = Duration(seconds: 90); // Text generation - increased for slower models

/// Image model options available on Pollinations
enum PollinationsModel {
  flux('flux', 'FLUX (Best Quality)'),
  fluxRealism('flux-realism', 'FLUX Realism'),
  fluxAnime('flux-anime', 'FLUX Anime'),
  fluxCablyai('flux-cablyai', 'FLUX CablyAI'),
  turbo('turbo', 'Turbo (Fast)');

  final String modelId;
  final String displayName;

  const PollinationsModel(this.modelId, this.displayName);
}

/// Text model options available on Pollinations
/// FREE TIER: openai, openai-fast, bidara
/// SEED TIER: deepseek, gemini, gemini-search, mistral, qwen-coder
enum PollinationsTextModel {
  // Free models (anonymous tier)
  openai('openai', 'GPT-5 Nano', 'FREE - OpenAI latest'),
  openaifast('openai-fast', 'GPT-4.1 Nano', 'FREE - Super fast'),
  bidara('bidara', 'BIDARA (NASA)', 'FREE - NASA research assistant'),
  
  // Paid models (seed tier) - will fallback to openai if 402
  deepseek('deepseek', 'DeepSeek V3.1', 'Reasoning (requires tier)'),
  geminiSearch('gemini-search', 'Gemini Search', 'Google Search (requires tier)'),
  mistral('mistral', 'Mistral 3.2', 'Fast (requires tier)'),
  qwenCoder('qwen-coder', 'Qwen Coder', 'Code expert (requires tier)');

  final String modelId;
  final String displayName;
  final String description;

  const PollinationsTextModel(this.modelId, this.displayName, this.description);
}

/// Response from Pollinations API
class PollinationsResponse {
  final bool success;
  final Uint8List? imageData;
  final String? imagePath;
  final String? imageUrl; // URL for web compatibility
  final String? text;
  final String? error;

  PollinationsResponse({
    required this.success,
    this.imageData,
    this.imagePath,
    this.imageUrl,
    this.text,
    this.error,
  });

  factory PollinationsResponse.success({Uint8List? image, String? imagePath, String? imageUrl, String? text}) {
    return PollinationsResponse(success: true, imageData: image, imagePath: imagePath, imageUrl: imageUrl, text: text);
  }

  factory PollinationsResponse.failure(String error) {
    return PollinationsResponse(success: false, error: error);
  }
}

/// Pollinations AI Service - Free Image Generation
class PollinationsService {
  static final PollinationsService _instance = PollinationsService._internal();
  factory PollinationsService() => _instance;
  PollinationsService._internal();

  final http.Client _client = http.Client();
  String? _cacheDir;

  /// Initialize the service
  Future<void> initialize() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _cacheDir = '${appDir.path}/pollinations_images';
      final dir = Directory(_cacheDir!);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    } catch (e) {
      print('[Pollinations] Failed to create cache dir: $e');
    }
  }

  /// Generate an image from text prompt
  /// 
  /// Uses Pollinations.ai free API - no key required
  /// Returns the image URL for web compatibility
  Future<PollinationsResponse> generateImage({
    required String prompt,
    PollinationsModel model = PollinationsModel.flux,
    int width = 1024,
    int height = 1024,
    int seed = 0, // 0 = random
    bool enhance = true,
    bool nologo = true,
  }) async {
    try {
      print('[Pollinations] Generating image with ${model.displayName}...');
      print('[Pollinations] Prompt: $prompt');

      // Build URL with parameters
      // Format: https://image.pollinations.ai/prompt/{prompt}?model={model}&width={width}&height={height}&seed={seed}&enhance={enhance}&nologo={nologo}
      final encodedPrompt = Uri.encodeComponent(prompt);
      final queryParams = <String, String>{
        'model': model.modelId,
        'width': width.toString(),
        'height': height.toString(),
        'nologo': nologo.toString(),
      };
      
      if (enhance) {
        queryParams['enhance'] = 'true';
      }
      
      if (seed > 0) {
        queryParams['seed'] = seed.toString();
      }

      final uri = Uri.parse('$_pollinationsImageUrl/$encodedPrompt')
          .replace(queryParameters: queryParams);

      print('[Pollinations] Image URL: $uri');
      
      // For web compatibility, just return the URL directly instead of downloading
      // The image will be displayed using Image.network()
      return PollinationsResponse.success(imageUrl: uri.toString());
      
    } on SocketException {
      print('[Pollinations] Network error');
      return PollinationsResponse.failure('Network error - check your connection');
    } catch (e) {
      print('[Pollinations] Exception: $e');
      return PollinationsResponse.failure('Image generation error: $e');
    }
  }

  /// Save image to local cache
  Future<String> _saveImage(Uint8List bytes) async {
    if (_cacheDir == null) await initialize();

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    // Detect format from magic bytes
    String ext = 'png';
    if (bytes.length > 2) {
      if (bytes[0] == 0xFF && bytes[1] == 0xD8) ext = 'jpg';
      else if (bytes.length > 12 && bytes[0] == 0x52 && bytes[1] == 0x49) ext = 'webp';
    }
    
    final path = '$_cacheDir/pollinations_$timestamp.$ext';
    final file = File(path);
    await file.writeAsBytes(bytes);
    print('[Pollinations] Saved image to: $path');
    return path;
  }

  /// Generate text response using Pollinations text API
  /// 
  /// Uses models with recent 2024-2025 knowledge!
  /// Available models: OpenAI, DeepSeek V3, Mistral, Llama, Qwen
  Future<PollinationsResponse> generateText({
    required String prompt,
    PollinationsTextModel model = PollinationsTextModel.openai,
    String? systemPrompt,
    bool jsonMode = false,
  }) async {
    try {
      print('[Pollinations] Generating text with ${model.displayName}...');
      print('[Pollinations] Prompt: ${prompt.substring(0, prompt.length.clamp(0, 100))}...');

      // Build messages for chat format
      final messages = <Map<String, String>>[
        if (systemPrompt != null && systemPrompt.isNotEmpty)
          {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': prompt},
      ];

      // Build request body (OpenAI-compatible format)
      final requestBody = <String, dynamic>{
        'messages': messages,
        'model': model.modelId,
        if (jsonMode) 'response_format': {'type': 'json_object'},
      };

      final response = await _client.post(
        Uri.parse(_pollinationsTextUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      ).timeout(_textTimeout);

      print('[Pollinations] Text response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        // Parse response - OpenAI format: {choices: [{message: {content: ...}}]}
        String? text;
        try {
          final data = json.decode(response.body);
          // Check various formats
          if (data is String) {
            text = data;
          } else if (data is Map) {
            // OpenAI format first
            text = data['choices']?[0]?['message']?['content']?.toString() ??
                   data['content']?.toString() ??
                   data['text']?.toString() ??
                   data['response']?.toString();
          }
        } catch (e) {
          // Assume plain text response
          text = response.body;
        }

        if (text != null && text.isNotEmpty) {
          print('[Pollinations] Text generated (${text.length} chars)');
          return PollinationsResponse.success(text: text);
        }
        return PollinationsResponse.failure('Empty response from Pollinations');
      } else if (response.statusCode == 429) {
        return PollinationsResponse.failure('Rate limited - try again in a moment');
      } else if (response.statusCode == 402) {
        // Tier requirement - try fallback to openai model
        print('[Pollinations] Model requires higher tier, trying default openai model');
        if (model != PollinationsTextModel.openai) {
          return generateText(
            prompt: prompt,
            model: PollinationsTextModel.openai,
            systemPrompt: systemPrompt,
            jsonMode: jsonMode,
          );
        }
        return PollinationsResponse.failure('Model unavailable - try another model');
      } else {
        return PollinationsResponse.failure('Text generation failed: ${response.statusCode}');
      }
    } on SocketException {
      print('[Pollinations] Network error');
      return PollinationsResponse.failure('Network error - check your connection');
    } catch (e) {
      print('[Pollinations] Text exception: $e');
      return PollinationsResponse.failure('Text generation error: $e');
    }
  }

  /// Chat response for AI chat screen
  Future<PollinationsResponse> chatResponse({
    required String userMessage,
    String? pageContext,
    PollinationsTextModel model = PollinationsTextModel.openai,
  }) async {
    final systemPrompt = '''You are Dino AI, a helpful browser assistant for Dino Browser.
You have knowledge up to December 2025 - you know about recent events!
When discussing recent news or events, be specific with dates and details.
If you're unsure about very recent events, say so honestly.
Format responses with markdown: use **bold**, bullet points, and ## headings.
Be concise but comprehensive.''';

    String fullPrompt = userMessage;
    if (pageContext != null && pageContext.isNotEmpty) {
      fullPrompt = '''$userMessage

---
**Current Page Context:**
$pageContext''';
    }

    return generateText(
      prompt: fullPrompt,
      model: model,
      systemPrompt: systemPrompt,
    );
  }

  /// Clean up resources
  void dispose() {
    _client.close();
  }
}
