/// Splash Screen
/// 
/// Animated app launch screen with Dino branding
library;

import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../config/theme.dart';
import 'browser_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToHome();
  }

  Future<void> _navigateToHome() async {
    await Future.delayed(const Duration(milliseconds: 2000));
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const BrowserScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DinoColors.darkBg,
      body: Container(
        decoration: const BoxDecoration(gradient: DinoGradients.darkGradient),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Dino logo
              ZoomIn(
                duration: const Duration(milliseconds: 600),
                child: Container(
                  width: 120, height: 120,
                  decoration: BoxDecoration(
                    gradient: DinoGradients.primaryGradient,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [BoxShadow(color: DinoColors.cyberGreen.withAlpha(100), blurRadius: 30, spreadRadius: 5)],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: Image.asset(
                      'assets/icon/dino_logo.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.pets, size: 60, color: DinoColors.deepJungle);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              // App name
              FadeInUp(
                delay: const Duration(milliseconds: 300),
                duration: const Duration(milliseconds: 500),
                child: Text('DINO', style: Theme.of(context).textTheme.displayLarge?.copyWith(color: DinoColors.cyberGreen, fontWeight: FontWeight.bold, letterSpacing: 8)),
              ),
              FadeInUp(
                delay: const Duration(milliseconds: 500),
                duration: const Duration(milliseconds: 500),
                child: Text('BROWSER', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: DinoColors.textSecondary, letterSpacing: 12)),
              ),
              const SizedBox(height: 48),
              
              // Loading indicator
              FadeIn(
                delay: const Duration(milliseconds: 800),
                child: SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation<Color>(DinoColors.cyberGreen.withAlpha(180)))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
