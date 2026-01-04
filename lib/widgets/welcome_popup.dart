/// Welcome Popup Dialog
/// 
/// Shows a one-time welcome message to new users

import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';

class WelcomePopup {
  static const String _seenKeyPrefix = 'welcome_popup_seen_';
  
  /// Check if user has seen the popup (per-user tracking)
  static Future<bool> hasSeenPopup(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_seenKeyPrefix$userId') ?? false;
  }
  
  /// Mark popup as seen for this user
  static Future<void> markAsSeen(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_seenKeyPrefix$userId', true);
  }
  
  /// Show welcome popup if not seen by this user
  static Future<void> showIfNeeded(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.uid ?? 'anonymous';
    
    final hasSeen = await hasSeenPopup(userId);
    if (!hasSeen && context.mounted) {
      await show(context);
    }
  }
  
  /// Show the welcome popup
  static Future<void> show(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.uid ?? 'anonymous';
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (context) => const _WelcomeDialog(),
    );
    await markAsSeen(userId);
  }
}

class _WelcomeDialog extends StatelessWidget {
  const _WelcomeDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: FadeInUp(
        duration: const Duration(milliseconds: 400),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 400,
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [DinoColors.surfaceBg, DinoColors.darkBg],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: DinoColors.cyberGreen.withAlpha(100),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: DinoColors.cyberGreen.withAlpha(30),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with animated icon
                  Container(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // Animated Dino icon
                        BounceInDown(
                          delay: const Duration(milliseconds: 200),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                colors: [
                                  DinoColors.cyberGreen.withAlpha(50),
                                  Colors.transparent,
                                ],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Text('🦖', style: TextStyle(fontSize: 64)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Welcome text
                        FadeInUp(
                          delay: const Duration(milliseconds: 300),
                          child: const Text(
                            'Welcome to DINO Browser!',
                            style: TextStyle(
                              color: DinoColors.cyberGreen,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // Beta badge
                        FadeInUp(
                          delay: const Duration(milliseconds: 400),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: DinoColors.warning.withAlpha(30),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: DinoColors.warning.withAlpha(100)),
                            ),
                            child: const Text(
                              'EARLY ACCESS VERSION',
                              style: TextStyle(
                                color: DinoColors.warning,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Message body
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: FadeInUp(
                      delay: const Duration(milliseconds: 500),
                      child: const Text(
                        'Thank you for being an early adopter! You\'re using the first version of DINO Browser.\n\nYour feedback is invaluable in helping us improve.',
                        style: TextStyle(
                          color: DinoColors.textSecondary,
                          fontSize: 14,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Feedback callout
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: FadeInUp(
                      delay: const Duration(milliseconds: 600),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: DinoColors.cyberGreen.withAlpha(15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: DinoColors.cyberGreen.withAlpha(40)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.lightbulb_outline, color: DinoColors.cyberGreen, size: 24),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Share your thoughts:\nSettings → Feedback',
                                style: TextStyle(
                                  color: DinoColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Close button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: FadeInUp(
                      delay: const Duration(milliseconds: 700),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: DinoColors.cyberGreen,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.rocket_launch),
                              SizedBox(width: 8),
                              Text(
                                'Let\'s Explore!',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
