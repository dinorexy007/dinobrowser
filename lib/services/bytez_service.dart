/// Bytez AI Service - Fixed
/// 
/// Unified API client for Bytez AI models including:
/// - Text-to-Text (Qwen3, GPT2)
/// - Text-to-Image (SDXL, OpenJourney)
/// - Visual QA (VILT, BLIP)
/// 
/// API Documentation: https://docs.bytez.com/http-reference/overview
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Bytez API configuration
const String _bytezBaseUrl = 'https://api.bytez.com/models/v2';
const String _bytezApiKey = 'c894cdbea6de893f73c19db00d0b79d2';
const Duration _timeout = Duration(seconds: 120); // Increased for slow models
const int _maxRetries = 3; // Retry on concurrency errors

/// Available AI models
enum AiModelType {
  // Text-to-Text (chat models use messages format)
  qwen3('Qwen/Qwen3-4B-Instruct-2507', 'Qwen3 4B (Local)', 'text'),
  gpt2('openai-community/gpt2', 'GPT-2', 'text'),
  groq('groq-llama-70b', 'Groq Llama 3.3', 'text'), // Uses Groq API - Fast!
  
  // Pollinations AI Models - FREE!
  pollinationsGpt('pollinations-openai', '⭐ GPT-5 Nano (FREE)', 'text'), // Free OpenAI model
  pollinationsGptFast('pollinations-fast', '⚡ GPT-4.1 Nano (FREE)', 'text'), // Free fast model
  pollinationsBidara('pollinations-bidara', '🚀 BIDARA NASA (FREE)', 'text'), // Free NASA assistant
  
  // Pollinations AI Models - Paid tier (auto-fallback to free if 402)
  pollinationsDeepSeek('pollinations-deepseek', '🧠 DeepSeek V3.1', 'text'),
  pollinationsGeminiSearch('pollinations-gemini-search', '🔍 Gemini Search', 'text'), // Has Google Search!
  pollinationsMistral('pollinations-mistral', '⚡ Mistral 3.2', 'text'),
  pollinationsQwenCoder('pollinations-qwen-coder', '💻 Qwen Coder', 'text'),
  
  // Text-to-Image
  sdxl('stabilityai/stable-diffusion-xl-base-1.0', 'Stable Diffusion XL', 'image'),
  openjourney('prompthero/openjourney-v4', 'OpenJourney v4', 'image'),
  pollinationsFlux('pollinations-flux', 'Pollinations FLUX', 'image'), // Pollinations image generation
  
  // Visual QA
  vilt('dandelin/vilt-b32-finetuned-vqa', 'VILT VQA', 'vqa'),
  blip('Salesforce/blip-vqa-capfilt-large', 'BLIP VQA', 'vqa');

  final String modelId;
  final String displayName;
  final String type;
  
  const AiModelType(this.modelId, this.displayName, this.type);
  
  bool get isTextModel => type == 'text';
  bool get isImageModel => type == 'image';
  bool get isVqaModel => type == 'vqa';
  bool get isGroqModel => this == AiModelType.groq;
  bool get isPollinationsModel => this == AiModelType.pollinationsGpt || 
      this == AiModelType.pollinationsGptFast ||
      this == AiModelType.pollinationsBidara ||
      this == AiModelType.pollinationsDeepSeek ||
      this == AiModelType.pollinationsGeminiSearch ||
      this == AiModelType.pollinationsMistral ||
      this == AiModelType.pollinationsQwenCoder ||
      this == AiModelType.pollinationsFlux;
  
  /// Get the API endpoint for this model
  String get endpoint => '$_bytezBaseUrl/$modelId';
}

/// Response from Bytez API
class BytezResponse {
  final bool success;
  final String? textOutput;
  final Uint8List? imageData;
  final String? imagePath;
  final String? error;

  BytezResponse({
    required this.success,
    this.textOutput,
    this.imageData,
    this.imagePath,
    this.error,
  });

  factory BytezResponse.success({String? text, Uint8List? image, String? imagePath}) {
    return BytezResponse(
      success: true,
      textOutput: text,
      imageData: image,
      imagePath: imagePath,
    );
  }

  factory BytezResponse.failure(String error) {
    return BytezResponse(success: false, error: error);
  }
}

/// Bytez AI Service
class BytezService {
  static final BytezService _instance = BytezService._internal();
  factory BytezService() => _instance;
  BytezService._internal();

  final http.Client _client = http.Client();
  String? _cacheDir;
  bool _isRequestInProgress = false; // Track active requests to avoid concurrency

  /// Initialize the service
  Future<void> initialize() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _cacheDir = '${appDir.path}/ai_images';
      final dir = Directory(_cacheDir!);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    } catch (e) {
      // Non-fatal, images just won't be cached
    }
  }

  /// Make HTTP request with retry logic for concurrency errors
  Future<http.Response> _makeRequestWithRetry({
    required Uri uri,
    required Map<String, String> headers,
    required String body,
  }) async {
    // Wait if another request is in progress (avoid 1 concurrency limit)
    while (_isRequestInProgress) {
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    _isRequestInProgress = true;
    
    try {
      for (int attempt = 0; attempt < _maxRetries; attempt++) {
        try {
          final response = await _client.post(
            uri,
            headers: headers,
            body: body,
          ).timeout(_timeout);
          
          // Check for concurrency error
          if (response.statusCode == 429 || 
              (response.body.contains('concurrency') && response.statusCode >= 400)) {
            // Wait and retry with exponential backoff
            final waitTime = Duration(seconds: (attempt + 1) * 2);
            await Future.delayed(waitTime);
            continue;
          }
          
          return response;
        } on SocketException {
          if (attempt == _maxRetries - 1) rethrow;
          await Future.delayed(Duration(seconds: (attempt + 1) * 2));
        }
      }
      
      throw SocketException('Failed after $_maxRetries retries');
    } finally {
      _isRequestInProgress = false;
    }
  }

  /// Text-to-Text generation
  /// 
  /// Uses chat models like Qwen3 or GPT2 to generate text responses
  Future<BytezResponse> textToText({
    required String prompt,
    AiModelType model = AiModelType.qwen3,
    List<Map<String, String>>? chatHistory,
  }) async {
    try {
      Map<String, dynamic> body;
      
      // Qwen uses messages format (chat), GPT2 uses text format
      if (model == AiModelType.qwen3) {
        // Build messages for chat model
        final messages = <Map<String, String>>[];
        
        messages.add({
          'role': 'system',
          'content': 'You are Dino AI, a helpful browser assistant. '
              'Format responses with markdown: use **bold**, bullet points, and ## headings. '
              'Be concise but comprehensive.',
        });
        
        if (chatHistory != null) {
          messages.addAll(chatHistory);
        }
        
        messages.add({
          'role': 'user',
          'content': prompt,
        });
        
        body = {'messages': messages};
      } else {
        // GPT2 uses simple text input
        body = {
          'text': prompt,
          'stream': false,
          'params': {
            'max_length': 512,
            'temperature': 0.7,
          },
        };
      }

      final response = await _makeRequestWithRetry(
        uri: Uri.parse(model.endpoint),
        headers: {
          'Authorization': 'Bearer $_bytezApiKey',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Extract text from response - handle various formats
        String? text;
        if (data is String) {
          text = data;
        } else if (data is Map) {
          // Check if output is a nested object (Qwen3 format: {"output": {"content": "..."}})
          final output = data['output'];
          if (output is Map) {
            // Qwen3 returns {"output": {"role": "assistant", "content": "..."}}
            text = output['content']?.toString();
          } else if (output is String) {
            // GPT2 returns {"output": "..."}
            text = output;
          }
          
          // Fallback to other common fields
          text ??= data['text']?.toString() ?? 
                   data['generated_text']?.toString() ??
                   data['content']?.toString() ??
                   data['message']?.toString();
          
          // Handle nested choices array (OpenAI format)
          if (text == null && data['choices'] is List) {
            final choices = data['choices'] as List;
            if (choices.isNotEmpty) {
              text = choices[0]['message']?['content']?.toString() ??
                     choices[0]['text']?.toString();
            }
          }
        } else if (data is List && data.isNotEmpty) {
          text = data[0]['generated_text']?.toString() ?? 
                 data[0]['text']?.toString() ?? 
                 data[0].toString();
        }
        
        if (text != null && text.isNotEmpty) {
          return BytezResponse.success(text: text);
        }
        
        // If we can't parse, return raw response
        return BytezResponse.success(text: response.body);
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        return BytezResponse.failure('API authentication failed. Check API key.');
      } else {
        // Try to extract error message
        try {
          final errorData = json.decode(response.body);
          final errorMsg = errorData['error']?.toString() ?? 
                          errorData['message']?.toString() ?? 
                          'Server error: ${response.statusCode}';
          return BytezResponse.failure(errorMsg);
        } catch (e) {
          return BytezResponse.failure('Server error: ${response.statusCode}');
        }
      }
    } on SocketException {
      return BytezResponse.failure('Network error - check your connection');
    } on TimeoutException {
      return BytezResponse.failure('Request timed out - try again');
    } catch (e) {
      return BytezResponse.failure('Error: $e');
    }
  }

  /// Text-to-Image generation
  /// 
  /// Uses SDXL or OpenJourney to generate images from text prompts
  Future<BytezResponse> textToImage({
    required String prompt,
    AiModelType model = AiModelType.sdxl,
  }) async {
    try {
      print('[BytezImg] Starting image generation with ${model.displayName}');
      print('[BytezImg] Prompt: $prompt');
      print('[BytezImg] Endpoint: ${model.endpoint}');
      
      final response = await _client.post(
        Uri.parse(model.endpoint),
        headers: {
          'Authorization': 'Bearer $_bytezApiKey',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'text': prompt,
        }),
      ).timeout(_timeout);

      print('[BytezImg] Response status: ${response.statusCode}');
      print('[BytezImg] Content-Type: ${response.headers['content-type']}');
      print('[BytezImg] Body length: ${response.bodyBytes.length}');

      if (response.statusCode == 200) {
        // Check if response is image bytes directly
        final contentType = response.headers['content-type'] ?? '';
        if (contentType.contains('image')) {
          print('[BytezImg] Direct image bytes received');
          final imagePath = await _saveImage(response.bodyBytes);
          return BytezResponse.success(image: response.bodyBytes, imagePath: imagePath);
        }
        
        // Try to parse JSON response
        try {
          final data = json.decode(response.body);
          print('[BytezImg] JSON response keys: ${data.keys.toList()}');
          
          // Handle 'output' field from Bytez (most common format)
          if (data['output'] != null) {
            final output = data['output'];
            print('[BytezImg] Output type: ${output.runtimeType}');
            
            // Output could be base64 string, URL, or bytes
            if (output is String) {
              // Check if it's a data URL or base64
              if (output.startsWith('data:image')) {
                print('[BytezImg] Data URL detected');
                final base64Str = output.split(',').last;
                final bytes = base64Decode(base64Str);
                final imagePath = await _saveImage(bytes);
                return BytezResponse.success(image: bytes, imagePath: imagePath);
              } else if (output.startsWith('http')) {
                print('[BytezImg] Image URL detected: $output');
                final imageResponse = await _client.get(Uri.parse(output));
                if (imageResponse.statusCode == 200) {
                  final imagePath = await _saveImage(imageResponse.bodyBytes);
                  return BytezResponse.success(image: imageResponse.bodyBytes, imagePath: imagePath);
                }
              } else {
                // Assume it's raw base64
                print('[BytezImg] Assuming raw base64');
                try {
                  final bytes = base64Decode(output);
                  if (bytes.length > 1000) {
                    final imagePath = await _saveImage(bytes);
                    return BytezResponse.success(image: bytes, imagePath: imagePath);
                  }
                } catch (e) {
                  print('[BytezImg] Base64 decode failed: $e');
                }
              }
            } else if (output is List && output.isNotEmpty) {
              // Handle array of images - take first one
              final firstOutput = output[0];
              print('[BytezImg] Array output, first item type: ${firstOutput.runtimeType}');
              if (firstOutput is String) {
                if (firstOutput.startsWith('data:image')) {
                  final base64Str = firstOutput.split(',').last;
                  final bytes = base64Decode(base64Str);
                  final imagePath = await _saveImage(bytes);
                  return BytezResponse.success(image: bytes, imagePath: imagePath);
                } else if (firstOutput.startsWith('http')) {
                  final imageResponse = await _client.get(Uri.parse(firstOutput));
                  if (imageResponse.statusCode == 200) {
                    final imagePath = await _saveImage(imageResponse.bodyBytes);
                    return BytezResponse.success(image: imageResponse.bodyBytes, imagePath: imagePath);
                  }
                } else {
                  // Try as base64
                  try {
                    final bytes = base64Decode(firstOutput);
                    if (bytes.length > 1000) {
                      final imagePath = await _saveImage(bytes);
                      return BytezResponse.success(image: bytes, imagePath: imagePath);
                    }
                  } catch (e) {
                    print('[BytezImg] Base64 decode failed for array item: $e');
                  }
                }
              }
            }
          }
          
          // Handle 'image' field (base64 encoded)
          if (data['image'] != null) {
            print('[BytezImg] Found image field');
            String base64Str = data['image'].toString();
            // Remove data URL prefix if present
            if (base64Str.contains(',')) {
              base64Str = base64Str.split(',').last;
            }
            final bytes = base64Decode(base64Str);
            final imagePath = await _saveImage(bytes);
            return BytezResponse.success(image: bytes, imagePath: imagePath);
          }
          
          // Handle image URL
          if (data['url'] != null || data['image_url'] != null) {
            final imageUrl = data['url'] ?? data['image_url'];
            print('[BytezImg] Found URL field: $imageUrl');
            final imageResponse = await _client.get(Uri.parse(imageUrl));
            if (imageResponse.statusCode == 200) {
              final imagePath = await _saveImage(imageResponse.bodyBytes);
              return BytezResponse.success(image: imageResponse.bodyBytes, imagePath: imagePath);
            }
          }
          
          print('[BytezImg] Could not find image in response: ${response.body.substring(0, response.body.length.clamp(0, 500))}');
          return BytezResponse.failure('Could not extract image from response');
        } catch (e) {
          // Response might be raw image bytes without content-type
          print('[BytezImg] JSON parse failed, checking raw bytes: $e');
          if (response.bodyBytes.length > 1000) {
            // Check if bytes look like an image (PNG/JPEG magic bytes)
            final bytes = response.bodyBytes;
            if ((bytes[0] == 0x89 && bytes[1] == 0x50) || // PNG
                (bytes[0] == 0xFF && bytes[1] == 0xD8)) { // JPEG
              print('[BytezImg] Raw image bytes detected');
              final imagePath = await _saveImage(bytes);
              return BytezResponse.success(image: bytes, imagePath: imagePath);
            }
          }
          return BytezResponse.failure('Invalid image response: $e');
        }
      }
      
      // Handle error responses
      String errorMsg = 'Image generation failed: ${response.statusCode}';
      try {
        final errorData = json.decode(response.body);
        errorMsg = errorData['error']?.toString() ?? 
                  errorData['message']?.toString() ?? 
                  errorMsg;
      } catch (e) {
        // Keep default error message
      }
      print('[BytezImg] Error: $errorMsg');
      return BytezResponse.failure(errorMsg);
    } catch (e) {
      print('[BytezImg] Exception: $e');
      return BytezResponse.failure('Image generation error: $e');
    }
  }

  /// Visual Question Answering
  /// 
  /// Uses VILT or BLIP to answer questions about images
  Future<BytezResponse> visualQA({
    required String imageUrl,
    required String question,
    AiModelType model = AiModelType.blip,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse(model.endpoint),
        headers: {
          'Authorization': 'Bearer $_bytezApiKey',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'text': question,
          'url': imageUrl,
        }),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        String? answer;
        if (data is String) {
          answer = data;
        } else if (data is Map) {
          answer = data['answer']?.toString() ?? 
                   data['output']?.toString() ??
                   data['text']?.toString();
        } else if (data is List && data.isNotEmpty) {
          answer = data[0]['answer']?.toString() ?? data[0].toString();
        }
        
        if (answer != null && answer.isNotEmpty) {
          return BytezResponse.success(text: answer);
        }
        return BytezResponse.success(text: response.body);
      }
      
      return BytezResponse.failure('Visual QA failed: ${response.statusCode}');
    } catch (e) {
      return BytezResponse.failure('Visual QA error: $e');
    }
  }

  /// Save image to local cache
  Future<String> _saveImage(Uint8List bytes) async {
    if (_cacheDir == null) await initialize();
    
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = '$_cacheDir/ai_gen_$timestamp.png';
    final file = File(path);
    await file.writeAsBytes(bytes);
    return path;
  }

  /// Clean up resources
  void dispose() {
    _client.close();
  }
}

/// Timeout exception for type checking
class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
}
