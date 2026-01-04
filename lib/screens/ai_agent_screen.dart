/// AI Agent Screen - Enhanced
/// 
/// Dino-themed chat interface with multiple AI models:
/// - Text-to-Text (Qwen3, GPT2)
/// - Text-to-Image (SDXL, OpenJourney)
/// - Visual QA (VILT, BLIP)
/// 
/// Features: Model selector, image upload, chat history
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import '../config/theme.dart';
import '../providers/browser_provider.dart';
import '../providers/auth_provider.dart';
import '../services/bytez_service.dart';
import '../services/browser_tools.dart';
import '../services/database_service.dart';
import '../services/grok_service.dart';
import '../services/pollinations_service.dart';
import '../services/auth_service.dart';

/// Chat message model for enhanced AI
class ChatMessage {
  final int? id;
  final String content;
  final bool isUser;
  final bool isError;
  final String? imagePath;
  final String? imageUrl;
  final DateTime timestamp;
  final AiModelType? modelUsed;

  ChatMessage({
    this.id,
    required this.content,
    required this.isUser,
    this.isError = false,
    this.imagePath,
    this.imageUrl,
    this.modelUsed,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory ChatMessage.error(String message) {
    return ChatMessage(content: message, isUser: false, isError: true);
  }
  
  factory ChatMessage.image({required String path, String? prompt}) {
    return ChatMessage(
      content: prompt ?? 'Generated image',
      isUser: false,
      imagePath: path,
    );
  }
  
  factory ChatMessage.imageFromUrl({required String url, String? prompt}) {
    return ChatMessage(
      content: prompt ?? 'Generated image',
      isUser: false,
      imageUrl: url,
    );
  }
}

class AiAgentScreen extends StatefulWidget {
  const AiAgentScreen({super.key});

  @override
  State<AiAgentScreen> createState() => _AiAgentScreenState();
}

class _AiAgentScreenState extends State<AiAgentScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final BytezService _bytezService = BytezService();
  final DatabaseService _db = DatabaseService();
  final AuthService _authService = AuthService();
  final ImagePicker _imagePicker = ImagePicker();
  
  /// Get current user ID for data isolation
  String get _currentUserId => _authService.currentUser?.uid ?? 'anonymous';
  
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isLoadingHistory = true;
  
  // Selected model - default to FREE model
  AiModelType _selectedModel = AiModelType.pollinationsGpt;
  
  // Attached image for VQA
  String? _attachedImagePath;

  @override
  void initState() {
    super.initState();
    _bytezService.initialize();
    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    try {
      final savedMessages = await _db.getAiMessages(userId: _currentUserId, limit: 500);
      
      if (savedMessages.isEmpty) {
        setState(() {
          _messages.add(ChatMessage(
            content: "# 🦖 Welcome to Dino AI!\n\n"
                "I'm powered by **multiple AI models**!\n\n"
                "**⭐ FREE AI Models**\n"
                "- **GPT-5 Nano** - OpenAI's latest (FREE!)\n"
                "- **GPT-4.1 Nano** - Super fast (FREE!)\n"
                "- **BIDARA** - NASA research assistant (FREE!)\n\n"
                "**💳 Premium Models** (may require tier)\n"
                "- DeepSeek V3.1 - Best reasoning\n"
                "- **Gemini Search** - Has Google Search!\n"
                "- Mistral 3.2 / Qwen Coder\n\n"
                "**🎨 Image Generation**\n"
                "- Pollinations FLUX\n\n"
                "> 👉 Try the **FREE** models first!",
            isUser: false,
          ));
          _isLoadingHistory = false;
        });
      } else {
        final messages = savedMessages.map((row) => ChatMessage(
          id: row['id'] as int,
          content: row['content'] as String,
          isUser: row['is_user'] == 1,
          isError: row['is_error'] == 1,
          imageUrl: row['image_url'] as String?,
          timestamp: DateTime.tryParse(row['created_at'] ?? '') ?? DateTime.now(),
        )).toList();
        
        setState(() {
          _messages.addAll(messages);
          _isLoadingHistory = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      setState(() {
        _isLoadingHistory = false;
        _messages.add(ChatMessage(
          content: "# 🦖 Welcome to Dino AI!\n\nReady to help!",
          isUser: false,
        ));
      });
    }
  }

  Future<void> _saveMessage(ChatMessage message) async {
    try {
      await _db.saveAiMessage(
        userId: _currentUserId,
        content: message.content,
        isUser: message.isUser,
        isError: message.isError,
        imageUrl: message.imageUrl,
      );
    } catch (e) {
      // Silent fail
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isLoading) return;

    final message = text.trim();
    _controller.clear();

    // Check for image generation keywords
    final isImageRequest = _selectedModel.isImageModel || 
        message.toLowerCase().contains('generate image') ||
        message.toLowerCase().contains('create image') ||
        message.toLowerCase().contains('draw');

    final userMessage = ChatMessage(content: message, isUser: true);
    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });
    _scrollToBottom();
    await _saveMessage(userMessage);

    try {
      if (isImageRequest || _selectedModel.isImageModel) {
        // Image generation
        await _generateImage(message);
      } else if (_attachedImagePath != null && _selectedModel.isVqaModel) {
        // Visual QA
        await _analyzeImage(message);
      } else {
        // Text-to-text
        await _generateText(message);
      }
    } catch (e) {
      final errorMsg = ChatMessage.error(e.toString());
      setState(() {
        _messages.add(errorMsg);
        _isLoading = false;
      });
      await _saveMessage(errorMsg);
    }
    _scrollToBottom();
  }

  Future<void> _generateText(String prompt) async {
    try {
      String? pageContext;
      final provider = context.read<BrowserProvider>();
      
      if (provider.currentTab?.controller != null && !provider.currentTab!.isBlank) {
        final tools = BrowserTools(provider.currentTab!.controller!);
        final pageText = await tools.getPageText();
        final metadata = await tools.getPageMetadata();
        
        if (pageText.success) {
          pageContext = '**Page:** ${metadata.title}\n**URL:** ${metadata.url}\n\n${pageText.data}';
        }
      }

      print('[DinoAI] Sending request to ${_selectedModel.displayName}...');
      
      String? responseText;
      String? errorText;
      
      // Route to appropriate service based on model
      if (_selectedModel.isGroqModel) {
        // Use Groq API for fast responses (Llama 3.3 70B)
        final groq = GroqService();
        final response = await groq.generateResponse(
          prompt: prompt,
          pageContext: pageContext,
        );
        
        if (response.success && response.text != null) {
          responseText = response.text;
        } else {
          errorText = response.error ?? 'No response from Groq';
        }
      } else if (_selectedModel.isPollinationsModel && _selectedModel.isTextModel) {
        // Use Pollinations API for modern models with 2024-2025 knowledge!
        final pollinations = PollinationsService();
        await pollinations.initialize();
        
        // Map AiModelType to PollinationsTextModel
        PollinationsTextModel textModel;
        switch (_selectedModel) {
          case AiModelType.pollinationsGpt:
            textModel = PollinationsTextModel.openai;
            break;
          case AiModelType.pollinationsGptFast:
            textModel = PollinationsTextModel.openaifast;
            break;
          case AiModelType.pollinationsBidara:
            textModel = PollinationsTextModel.bidara;
            break;
          case AiModelType.pollinationsDeepSeek:
            textModel = PollinationsTextModel.deepseek;
            break;
          case AiModelType.pollinationsGeminiSearch:
            textModel = PollinationsTextModel.geminiSearch;
            break;
          case AiModelType.pollinationsMistral:
            textModel = PollinationsTextModel.mistral;
            break;
          case AiModelType.pollinationsQwenCoder:
            textModel = PollinationsTextModel.qwenCoder;
            break;
          default:
            textModel = PollinationsTextModel.openai;
            break;
        }
        
        final response = await pollinations.chatResponse(
          userMessage: prompt,
          pageContext: pageContext,
          model: textModel,
        );
        
        if (response.success && response.text != null) {
          responseText = response.text;
        } else {
          errorText = response.error ?? 'No response from Pollinations';
        }
      } else {
        // Use Bytez API for other models
        final response = await _bytezService.textToText(
          prompt: pageContext != null ? '$prompt\n\nPage content:\n$pageContext' : prompt,
          model: _selectedModel.isTextModel ? _selectedModel : AiModelType.qwen3,
        );
        
        if (response.success && response.textOutput != null) {
          responseText = response.textOutput;
        } else {
          errorText = response.error ?? 'No response from model';
        }
      }

      print('[DinoAI] Response received: hasText=${responseText != null}');

      if (responseText != null) {
        final aiMessage = ChatMessage(
          content: responseText,
          isUser: false,
          modelUsed: _selectedModel,
        );
        setState(() {
          _messages.add(aiMessage);
          _isLoading = false;
        });
        await _saveMessage(aiMessage);
      } else {
        print('[DinoAI] Error: $errorText');
        throw Exception(errorText);
      }
    } catch (e) {
      print('[DinoAI] Exception in _generateText: $e');
      final errorMsg = ChatMessage.error('Error: $e');
      setState(() {
        _messages.add(errorMsg);
        _isLoading = false;
      });
      await _saveMessage(errorMsg);
    }
  }

  Future<void> _generateImage(String prompt) async {
    try {
      print('[DinoAI] Generating image with Pollinations.ai...');
      
      // Use Pollinations.ai for free image generation
      final pollinations = PollinationsService();
      await pollinations.initialize();
      
      final response = await pollinations.generateImage(
        prompt: prompt,
        model: PollinationsModel.flux, // Best quality
        width: 1024,
        height: 1024,
        enhance: true,
        nologo: true,
      );

      if (response.success && response.imageUrl != null) {
        print('[DinoAI] Image URL generated: ${response.imageUrl}');
        final imageMessage = ChatMessage.imageFromUrl(
          url: response.imageUrl!,
          prompt: '🎨 Generated: "$prompt"',
        );
        setState(() {
          _messages.add(imageMessage);
          _isLoading = false;
        });
        await _saveMessage(imageMessage);
      } else {
        print('[DinoAI] Image generation failed: ${response.error}');
        throw Exception(response.error ?? 'Failed to generate image');
      }
    } catch (e) {
      print('[DinoAI] Exception in _generateImage: $e');
      final errorMsg = ChatMessage.error('Image error: $e');
      setState(() {
        _messages.add(errorMsg);
        _isLoading = false;
      });
      await _saveMessage(errorMsg);
    }
  }

  Future<void> _analyzeImage(String question) async {
    if (_attachedImagePath == null) {
      throw Exception('Please attach an image first');
    }

    // For VQA, we need a URL - for local files, we'd need to upload
    // For now, show a limited message
    final aiMessage = ChatMessage(
      content: '🔍 Visual QA requires an image URL. '
          'This feature works best with web images. '
          'Please provide an image URL or use the summarize feature on a page with images.',
      isUser: false,
    );
    setState(() {
      _messages.add(aiMessage);
      _isLoading = false;
      _attachedImagePath = null;
    });
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      
      if (image != null) {
        setState(() {
          _attachedImagePath = image.path;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DinoColors.surfaceBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: DinoColors.error),
            SizedBox(width: 8),
            Text('Clear Chat?', style: TextStyle(color: DinoColors.textPrimary)),
          ],
        ),
        content: const Text(
          'This will delete all chat history.',
          style: TextStyle(color: DinoColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: DinoColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: DinoColors.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _db.clearAiMessages(userId: _currentUserId);
      setState(() {
        _messages.clear();
        _messages.add(ChatMessage(
          content: "# 🦖 Chat Cleared\n\nHow can I help you?",
          isUser: false,
        ));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Gate behind login
        if (!authProvider.isLoggedIn) {
          return _buildLoginPrompt();
        }

        return Scaffold(
          backgroundColor: DinoColors.darkBg,
          appBar: _buildAppBar(),
          body: _isLoadingHistory
              ? const Center(child: CircularProgressIndicator(color: DinoColors.cyberGreen))
              : Column(
                  children: [
                    _buildModelSelector(),
                    Expanded(child: _buildMessageList()),
                    if (_attachedImagePath != null) _buildAttachedImage(),
                    _buildInputArea(),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildLoginPrompt() {
    return Scaffold(
      backgroundColor: DinoColors.darkBg,
      appBar: AppBar(
        backgroundColor: DinoColors.surfaceBg,
        title: const Text('🦖 Dino AI'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🔐', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 24),
              const Text(
                'Sign in to use Dino AI',
                style: TextStyle(
                  color: DinoColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Dino AI is available for registered users.',
                style: TextStyle(color: DinoColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/auth'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DinoColors.cyberGreen,
                  foregroundColor: DinoColors.deepJungle,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: const Text('Sign In'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: DinoColors.surfaceBg,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: DinoColors.textPrimary),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [DinoColors.cyberGreen, Color(0xFF00D4AA)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(child: Text('🦖', style: TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 12),
          const Text('Dino AI', style: TextStyle(color: DinoColors.textPrimary, fontWeight: FontWeight.bold)),
        ],
      ),
      actions: [
        // History button
        IconButton(
          icon: const Icon(Icons.history, color: DinoColors.textSecondary),
          tooltip: 'Chat History',
          onPressed: _showHistorySheet,
        ),
        // Clear chat button
        IconButton(
          icon: const Icon(Icons.delete_outline, color: DinoColors.textSecondary),
          tooltip: 'Clear Chat',
          onPressed: _clearHistory,
        ),
      ],
    );
  }

  /// Show chat history bottom sheet
  void _showHistorySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: DinoColors.surfaceBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => _HistorySheet(
          messages: _messages,
          scrollController: scrollController,
          onDeleteMessage: (index) async {
            final msg = _messages[index];
            if (msg.id != null) {
              await _db.deleteAiMessage(msg.id!, userId: _currentUserId);
            }
            setState(() => _messages.removeAt(index));
            Navigator.pop(context);
          },
          onJumpToMessage: (index) {
            Navigator.pop(context);
            // Scroll to the message
            Future.delayed(const Duration(milliseconds: 200), () {
              if (_scrollController.hasClients) {
                // Approximate scroll position based on message index
                final targetOffset = index * 100.0;
                _scrollController.animateTo(
                  targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              }
            });
          },
        ),
      ),
    );
  }

  Widget _buildModelSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: DinoColors.surfaceBg,
        border: Border(bottom: BorderSide(color: DinoColors.glassBorder)),
      ),
      child: Row(
        children: [
          const Icon(Icons.smart_toy, color: DinoColors.cyberGreen, size: 20),
          const SizedBox(width: 8),
          const Text('Model:', style: TextStyle(color: DinoColors.textSecondary, fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: DinoColors.cardBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: DinoColors.glassBorder),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<AiModelType>(
                  value: _selectedModel,
                  isExpanded: true,
                  dropdownColor: DinoColors.cardBg,
                  style: const TextStyle(color: DinoColors.textPrimary, fontSize: 13),
                  items: AiModelType.values.map((model) {
                    IconData icon;
                    if (model.isTextModel) icon = Icons.chat;
                    else if (model.isImageModel) icon = Icons.image;
                    else icon = Icons.search;
                    
                    return DropdownMenuItem(
                      value: model,
                      child: Row(
                        children: [
                          Icon(icon, size: 16, color: DinoColors.cyberGreen),
                          const SizedBox(width: 8),
                          Text(model.displayName),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _selectedModel = value);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length && _isLoading) {
          return _buildTypingIndicator();
        }
        return FadeInUp(
          duration: const Duration(milliseconds: 300),
          child: _ChatBubble(message: _messages[index]),
        );
      },
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: DinoColors.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: DinoColors.glassBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🦖', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            SizedBox(
              width: 40,
              child: LinearProgressIndicator(
                backgroundColor: DinoColors.glassBorder,
                valueColor: AlwaysStoppedAnimation(DinoColors.cyberGreen),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _selectedModel.isImageModel ? 'Generating...' : 'Thinking...',
              style: TextStyle(color: DinoColors.textMuted.withAlpha(180), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachedImage() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: DinoColors.surfaceBg,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(_attachedImagePath!),
              width: 60, height: 60,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Image attached', style: TextStyle(color: DinoColors.textSecondary)),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: DinoColors.textMuted),
            onPressed: () => setState(() => _attachedImagePath = null),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DinoColors.surfaceBg,
        border: Border(top: BorderSide(color: DinoColors.glassBorder)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Image attach button (for VQA models)
            IconButton(
              icon: Icon(
                Icons.add_photo_alternate,
                color: _selectedModel.isVqaModel ? DinoColors.cyberGreen : DinoColors.textMuted,
              ),
              onPressed: _selectedModel.isVqaModel ? _pickImage : null,
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: DinoColors.cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: DinoColors.glassBorder),
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  style: const TextStyle(color: DinoColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: _selectedModel.isImageModel 
                        ? 'Describe the image to generate...'
                        : 'Ask Dino AI...',
                    hintStyle: TextStyle(color: DinoColors.textMuted.withAlpha(150)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: _sendMessage,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [DinoColors.cyberGreen, Color(0xFF00D4AA)]),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => _sendMessage(_controller.text),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Icon(
                      _selectedModel.isImageModel ? Icons.brush : Icons.send_rounded,
                      color: DinoColors.deepJungle, size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Chat bubble with image support
class _ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        decoration: BoxDecoration(
          gradient: message.isUser
              ? const LinearGradient(colors: [DinoColors.cyberGreen, Color(0xFF00D4AA)])
              : null,
          color: message.isUser ? null : DinoColors.cardBg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(message.isUser ? 20 : 4),
            bottomRight: Radius.circular(message.isUser ? 4 : 20),
          ),
          border: message.isUser ? null : Border.all(
            color: message.isError ? DinoColors.error.withAlpha(100) : DinoColors.glassBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.isError)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: DinoColors.error.withAlpha(30),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, color: DinoColors.error, size: 16),
                    SizedBox(width: 6),
                    Text('Error', style: TextStyle(color: DinoColors.error, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
            
            // Image display - support both file path (native) and URL (web)
            if (message.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  message.imageUrl!,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      width: 300,
                      height: 200,
                      color: DinoColors.cardBg,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                              color: DinoColors.cyberGreen,
                            ),
                            const SizedBox(height: 12),
                            const Text('Generating image...', 
                              style: TextStyle(color: DinoColors.textMuted)),
                          ],
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 300,
                      height: 200,
                      color: DinoColors.cardBg,
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, color: DinoColors.error, size: 40),
                            SizedBox(height: 8),
                            Text('Failed to load image', style: TextStyle(color: DinoColors.textMuted)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (message.imagePath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  File(message.imagePath!),
                  fit: BoxFit.cover,
                ),
              ),
            
            Padding(
              padding: const EdgeInsets.all(16),
              child: message.isUser
                  ? Text(message.content, style: const TextStyle(color: DinoColors.deepJungle, fontSize: 15))
                  : MarkdownBody(
                      data: message.content,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet(
                        h1: const TextStyle(color: DinoColors.cyberGreen, fontSize: 20, fontWeight: FontWeight.bold),
                        h2: const TextStyle(color: DinoColors.cyberGreen, fontSize: 18, fontWeight: FontWeight.bold),
                        p: const TextStyle(color: DinoColors.textPrimary, fontSize: 14, height: 1.6),
                        strong: const TextStyle(color: DinoColors.textPrimary, fontWeight: FontWeight.bold),
                        listBullet: const TextStyle(color: DinoColors.cyberGreen),
                        code: TextStyle(color: DinoColors.cyberGreen, backgroundColor: DinoColors.darkBg.withAlpha(150)),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chat history bottom sheet with grouped messages by date
class _HistorySheet extends StatelessWidget {
  final List<ChatMessage> messages;
  final ScrollController scrollController;
  final Function(int) onDeleteMessage;
  final Function(int) onJumpToMessage;

  const _HistorySheet({
    required this.messages,
    required this.scrollController,
    required this.onDeleteMessage,
    required this.onJumpToMessage,
  });

  @override
  Widget build(BuildContext context) {
    // Group messages by date
    final groupedMessages = <String, List<MapEntry<int, ChatMessage>>>{};
    for (int i = 0; i < messages.length; i++) {
      final msg = messages[i];
      final dateKey = _formatDateKey(msg.timestamp);
      groupedMessages.putIfAbsent(dateKey, () => []);
      groupedMessages[dateKey]!.add(MapEntry(i, msg));
    }

    final dateGroups = groupedMessages.entries.toList();

    return Column(
      children: [
        // Handle bar
        Container(
          margin: const EdgeInsets.only(top: 12),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: DinoColors.textMuted,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        
        // Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.history, color: DinoColors.cyberGreen, size: 24),
              const SizedBox(width: 12),
              const Text(
                'Chat History',
                style: TextStyle(
                  color: DinoColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${messages.length} messages',
                style: const TextStyle(color: DinoColors.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
        const Divider(color: DinoColors.glassBorder, height: 1),
        
        // Messages list
        Expanded(
          child: messages.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline, color: DinoColors.textMuted, size: 48),
                      SizedBox(height: 16),
                      Text('No chat history yet', style: TextStyle(color: DinoColors.textSecondary)),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: scrollController,
                  itemCount: dateGroups.length,
                  itemBuilder: (context, groupIndex) {
                    final dateEntry = dateGroups[groupIndex];
                    final dateKey = dateEntry.key;
                    final msgEntries = dateEntry.value;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          color: DinoColors.darkBg,
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, color: DinoColors.textMuted, size: 14),
                              const SizedBox(width: 8),
                              Text(
                                dateKey,
                                style: const TextStyle(
                                  color: DinoColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${msgEntries.length} messages',
                                style: const TextStyle(color: DinoColors.textMuted, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                        
                        // Messages in this date group
                        ...msgEntries.map((entry) {
                          final index = entry.key;
                          final msg = entry.value;
                          return _HistoryMessageTile(
                            message: msg,
                            onTap: () => onJumpToMessage(index),
                            onDelete: () => onDeleteMessage(index),
                          );
                        }),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _formatDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);
    
    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else if (now.difference(messageDate).inDays < 7) {
      const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      return weekdays[date.weekday - 1];
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

/// Single message tile in history view
class _HistoryMessageTile extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _HistoryMessageTile({
    required this.message,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: DinoColors.glassBorder, width: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon indicating user or AI
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: message.isUser 
                    ? DinoColors.cyberGreen.withAlpha(30)
                    : DinoColors.cardBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: message.isUser
                    ? const Icon(Icons.person, color: DinoColors.cyberGreen, size: 18)
                    : const Text('🦖', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(width: 12),
            
            // Message content preview
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        message.isUser ? 'You' : 'Dino AI',
                        style: TextStyle(
                          color: message.isUser ? DinoColors.cyberGreen : DinoColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(message.timestamp),
                        style: const TextStyle(color: DinoColors.textMuted, fontSize: 11),
                      ),
                      if (message.isError) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.error, color: DinoColors.error, size: 14),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message.content.replaceAll('\n', ' ').trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: DinoColors.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            
            // Delete button
            IconButton(
              icon: const Icon(Icons.delete_outline, color: DinoColors.textMuted, size: 18),
              onPressed: onDelete,
              tooltip: 'Delete message',
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
