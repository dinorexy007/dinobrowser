/// Dino Loading Widget
/// 
/// Animated loading widget with running dino character
/// Used during account setup and login processes
library;

import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../config/theme.dart';

class DinoLoadingWidget extends StatefulWidget {
  final String message;
  final bool showDino;
  
  const DinoLoadingWidget({
    super.key,
    this.message = 'Setting up your cave...',
    this.showDino = true,
  });

  @override
  State<DinoLoadingWidget> createState() => _DinoLoadingWidgetState();
}

class _DinoLoadingWidgetState extends State<DinoLoadingWidget>
    with TickerProviderStateMixin {
  late AnimationController _runController;
  late AnimationController _bounceController;
  late AnimationController _dotsController;
  late Animation<double> _bounceAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // Running animation (horizontal movement)
    _runController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
    
    // Bouncing animation (vertical hop)
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    )..repeat(reverse: true);
    
    _bounceAnimation = Tween<double>(begin: 0, end: -15).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );
    
    // Loading dots animation
    _dotsController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _runController.dispose();
    _bounceController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: DinoGradients.darkGradient,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.showDino) ...[
              // Animated Dino
              SizedBox(
                height: 120,
                width: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Ground line
                    Positioned(
                      bottom: 10,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              DinoColors.cyberGreen.withAlpha(128),
                              DinoColors.cyberGreen,
                              DinoColors.cyberGreen.withAlpha(128),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Running dino
                    AnimatedBuilder(
                      animation: _runController,
                      builder: (context, child) {
                        return AnimatedBuilder(
                          animation: _bounceAnimation,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(
                                math.sin(_runController.value * 2 * math.pi) * 30,
                                _bounceAnimation.value,
                              ),
                              child: _buildDino(),
                            );
                          },
                        );
                      },
                    ),
                    
                    // Dust particles
                    AnimatedBuilder(
                      animation: _runController,
                      builder: (context, child) {
                        return Positioned(
                          bottom: 15,
                          left: 50 + math.sin(_runController.value * 2 * math.pi) * 30,
                          child: Opacity(
                            opacity: 0.5,
                            child: Row(
                              children: List.generate(3, (index) {
                                final delay = index * 0.1;
                                final alphaValue = ((1 - ((_runController.value + delay) % 1)) * 0.6 * 255).round();
                                return Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Container(
                                    width: 4 + index * 2,
                                    height: 4 + index * 2,
                                    decoration: BoxDecoration(
                                      color: DinoColors.cyberGreen.withAlpha(alphaValue),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
            ],
            
            // Loading message with animated dots
            AnimatedBuilder(
              animation: _dotsController,
              builder: (context, child) {
                final dotCount = ((_dotsController.value * 4).floor() % 4);
                final dots = '.' * dotCount;
                return Text(
                  '${widget.message}$dots',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: DinoColors.textSecondary,
                    letterSpacing: 1,
                  ),
                );
              },
            ),
            
            const SizedBox(height: 24),
            
            // Loading bar
            SizedBox(
              width: 200,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: null,
                  backgroundColor: DinoColors.cardBg,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    DinoColors.cyberGreen.withAlpha(204),
                  ),
                  minHeight: 6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDino() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: DinoGradients.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: DinoColors.cyberGreen.withAlpha(102),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Text(
        '🦖',
        style: TextStyle(fontSize: 40),
      ),
    );
  }
}

/// Simple loading screen wrapper using DinoLoadingWidget
class DinoLoadingScreen extends StatelessWidget {
  final String message;
  
  const DinoLoadingScreen({
    super.key,
    this.message = 'Setting up your cave...',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DinoLoadingWidget(message: message),
    );
  }
}
