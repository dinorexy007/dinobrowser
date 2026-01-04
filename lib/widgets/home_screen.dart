/// Home Screen Widget
/// 
/// Interactive new tab home screen with beautiful dino design
/// Displays quick links to popular sites like Google, YouTube, ChatGPT
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import '../config/theme.dart';
import '../providers/browser_provider.dart';
import '../providers/auth_provider.dart';

class HomeScreen extends StatelessWidget {
  final Function(String url) onNavigate;

  const HomeScreen({
    super.key,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: DinoGradients.darkGradient,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 40),
              
              // Dino mascot with glow effect
              FadeInDown(
                duration: const Duration(milliseconds: 600),
                child: _buildDinoMascot(),
              ),
              
              const SizedBox(height: 24),
              
              // Welcome text
              FadeInDown(
                delay: const Duration(milliseconds: 200),
                child: _buildWelcomeText(context),
              ),
              
              const SizedBox(height: 48),
              
              // Quick links section
              FadeInUp(
                delay: const Duration(milliseconds: 400),
                child: _buildQuickLinksSection(context),
              ),
              
              const SizedBox(height: 32),
              
              // Recent sites / Speed dial
              FadeInUp(
                delay: const Duration(milliseconds: 500),
                child: _buildSpeedDialSection(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDinoMascot() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Glow effect
        Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: DinoColors.cyberGreen.withAlpha(60),
                blurRadius: 80,
                spreadRadius: 20,
              ),
              BoxShadow(
                color: DinoColors.raptorPurple.withAlpha(40),
                blurRadius: 60,
                spreadRadius: 10,
              ),
            ],
          ),
        ),
        
        // Main dino container
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            gradient: DinoGradients.primaryGradient,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: DinoColors.cyberGreen.withAlpha(100),
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: DinoColors.cyberGreen.withAlpha(80),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Center(
            child: Text(
              '🦖',
              style: TextStyle(fontSize: 70),
            ),
          ),
        ),
        
        // Sparkle effects
        Positioned(
          top: 10,
          right: 20,
          child: Pulse(
            infinite: true,
            duration: const Duration(milliseconds: 2000),
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: DinoColors.cyberGreen,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: DinoColors.cyberGreen.withAlpha(150),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 15,
          left: 15,
          child: Pulse(
            infinite: true,
            delay: const Duration(milliseconds: 500),
            duration: const Duration(milliseconds: 2000),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: DinoColors.raptorPurple,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: DinoColors.raptorPurple.withAlpha(150),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeText(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        final greeting = _getGreeting();
        final name = auth.isLoggedIn ? auth.displayName : 'Explorer';
        
        return Column(
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [DinoColors.cyberGreen, DinoColors.pterodactylBlue],
              ).createShader(bounds),
              child: Text(
                'DINO',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 12,
                  shadows: [
                    Shadow(
                      color: DinoColors.cyberGreen.withAlpha(150),
                      blurRadius: 20,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$greeting, $name',
              style: const TextStyle(
                fontSize: 16,
                color: DinoColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Widget _buildQuickLinksSection(BuildContext context) {
    final quickLinks = [
      _QuickLink(
        name: 'Google',
        url: 'https://www.google.com',
        icon: '🔍',
        gradient: const LinearGradient(
          colors: [Color(0xFF4285F4), Color(0xFF34A853)],
        ),
      ),
      _QuickLink(
        name: 'YouTube',
        url: 'https://www.youtube.com',
        icon: '▶️',
        gradient: const LinearGradient(
          colors: [Color(0xFFFF0000), Color(0xFFCC0000)],
        ),
      ),
      _QuickLink(
        name: 'ChatGPT',
        url: 'https://chat.openai.com',
        icon: '🤖',
        gradient: const LinearGradient(
          colors: [Color(0xFF10A37F), Color(0xFF1A7F64)],
        ),
      ),
      _QuickLink(
        name: 'Wikipedia',
        url: 'https://www.wikipedia.org',
        icon: '📚',
        gradient: const LinearGradient(
          colors: [Color(0xFF636466), Color(0xFF4A4A4A)],
        ),
      ),
      _QuickLink(
        name: 'GitHub',
        url: 'https://github.com',
        icon: '💻',
        gradient: const LinearGradient(
          colors: [Color(0xFF6e5494), Color(0xFF24292e)],
        ),
      ),
      _QuickLink(
        name: 'Reddit',
        url: 'https://www.reddit.com',
        icon: '🔥',
        gradient: const LinearGradient(
          colors: [Color(0xFFFF4500), Color(0xFFFF5722)],
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: DinoColors.cyberGreen,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'QUICK ACCESS',
                style: TextStyle(
                  color: DinoColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: quickLinks.length,
          itemBuilder: (context, index) {
            final link = quickLinks[index];
            return FadeInUp(
              delay: Duration(milliseconds: 100 * index),
              child: _buildQuickLinkCard(link),
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuickLinkCard(_QuickLink link) {
    return GestureDetector(
      onTap: () => onNavigate(link.url),
      child: Container(
        decoration: BoxDecoration(
          color: DinoColors.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: DinoColors.glassBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(30),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: link.gradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  link.icon,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              link.name,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: DinoColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedDialSection(BuildContext context) {
    return Consumer<BrowserProvider>(
      builder: (context, provider, child) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: provider.getSpeedDial(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const SizedBox.shrink();
            }

            final speedDial = snapshot.data!.take(6).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 20,
                        decoration: BoxDecoration(
                          color: DinoColors.raptorPurple,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'FREQUENTLY VISITED',
                        style: TextStyle(
                          color: DinoColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: speedDial.map((site) {
                    return GestureDetector(
                      onTap: () => onNavigate(site['url']),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: DinoColors.cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: DinoColors.glassBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: DinoColors.surfaceBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.public,
                                  size: 14,
                                  color: DinoColors.textMuted,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _extractDomain(site['url']),
                              style: const TextStyle(
                                fontSize: 12,
                                color: DinoColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.replaceFirst('www.', '');
    } catch (e) {
      return url;
    }
  }
}

class _QuickLink {
  final String name;
  final String url;
  final String icon;
  final LinearGradient gradient;

  const _QuickLink({
    required this.name,
    required this.url,
    required this.icon,
    required this.gradient,
  });
}
