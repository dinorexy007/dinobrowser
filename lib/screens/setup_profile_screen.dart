/// Setup Profile Screen
/// 
/// Shown after Google Sign-In for new users to enter their display name
/// Features dino-themed loading animation and profile customization
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart' as app_auth;
import '../providers/browser_provider.dart';
import '../widgets/dino_loading_widget.dart';

class SetupProfileScreen extends StatefulWidget {
  final bool isNewUser;
  
  const SetupProfileScreen({
    super.key,
    this.isNewUser = true,
  });

  @override
  State<SetupProfileScreen> createState() => _SetupProfileScreenState();
}

class _SetupProfileScreenState extends State<SetupProfileScreen> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSettingUp = true;
  String _loadingMessage = 'Setting up your cave...';

  @override
  void initState() {
    super.initState();
    _initializeProfile();
  }

  Future<void> _initializeProfile() async {
    // We no longer skip here because new Google users come with a displayName
    // and we want them to be able to confirm/change it.
    // Redirection for returning users is now handled by AuthScreen.

    // New user path with animations
    await Future.delayed(const Duration(milliseconds: 1500));
    
    setState(() {
      _loadingMessage = 'Preparing your browsing den...';
    });
    
    await Future.delayed(const Duration(milliseconds: 1000));
    
    // Clear browser session and reinitialize for the new user
    if (mounted) {
      final browserProvider = context.read<BrowserProvider>();
      await browserProvider.reinitializeForNewUser();
    }
    
    setState(() {
      _isSettingUp = false;
    });
    
    // Pre-fill with existing display name if available (fallback)
    final user = FirebaseAuth.instance.currentUser;
    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      _nameController.text = user.displayName!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.updateDisplayName(_nameController.text.trim());
      }
      
      // Refresh the AuthProvider to pick up the new display name
      if (mounted) {
        final authProvider = context.read<app_auth.AuthProvider>();
        await authProvider.refreshUser();
      }

      if (mounted) {
        // Navigate to browser
        Navigator.of(context).pushNamedAndRemoveUntil('/browser', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save profile: ${e.toString()}'),
            backgroundColor: DinoColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _skipForNow() {
    Navigator.of(context).pushNamedAndRemoveUntil('/browser', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isSettingUp) {
      return Scaffold(
        body: DinoLoadingWidget(message: _loadingMessage),
      );
    }

    return Scaffold(
      backgroundColor: DinoColors.darkBg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: DinoGradients.darkGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(DinoDimens.spacingLg),
            child: Column(
              children: [
                const SizedBox(height: 60),
                
                // Welcome Icon
                FadeInDown(
                  duration: const Duration(milliseconds: 500),
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: DinoGradients.primaryGradient,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: DinoColors.cyberGreen.withAlpha(77),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        '🦖',
                        style: TextStyle(fontSize: 50),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Title
                FadeInDown(
                  delay: const Duration(milliseconds: 200),
                  child: Text(
                    'Welcome to the Pack!',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: DinoColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Subtitle
                FadeInDown(
                  delay: const Duration(milliseconds: 300),
                  child: Text(
                    "What should we call you, explorer?",
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: DinoColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                const SizedBox(height: 48),
                
                // Name Input Form
                FadeInUp(
                  delay: const Duration(milliseconds: 400),
                  child: Form(
                    key: _formKey,
                    child: Container(
                      decoration: BoxDecoration(
                        color: DinoColors.cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: DinoColors.glassBorder),
                      ),
                      child: TextFormField(
                        controller: _nameController,
                        style: const TextStyle(
                          color: DinoColors.textPrimary,
                          fontSize: 18,
                        ),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: 'Enter your name',
                          hintStyle: TextStyle(
                            color: DinoColors.textMuted.withAlpha(179),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 20,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your name';
                          }
                          if (value.trim().length < 2) {
                            return 'Name must be at least 2 characters';
                          }
                          return null;
                        },
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _saveProfile(),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Continue Button
                FadeInUp(
                  delay: const Duration(milliseconds: 500),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DinoColors.cyberGreen,
                        foregroundColor: DinoColors.deepJungle,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 8,
                        shadowColor: DinoColors.cyberGreen.withAlpha(102),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: DinoColors.deepJungle,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Let's Explore!",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward, size: 20),
                              ],
                            ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Skip Option
                FadeInUp(
                  delay: const Duration(milliseconds: 600),
                  child: TextButton(
                    onPressed: _isLoading ? null : _skipForNow,
                    child: Text(
                      'Skip for now',
                      style: const TextStyle(
                        color: DinoColors.textMuted,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Info Card
                FadeInUp(
                  delay: const Duration(milliseconds: 700),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: DinoColors.cardBg.withAlpha(128),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: DinoColors.cyberGreen.withAlpha(51),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: DinoColors.cyberGreen.withAlpha(26),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.info_outline,
                            color: DinoColors.cyberGreen,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Your browsing data is synced across devices when signed in!',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: DinoColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
