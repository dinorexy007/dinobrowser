/// Tab Bar Widget
/// 
/// Horizontal tab bar with animated tab indicators
/// and smooth tab switching
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import '../config/theme.dart';
import '../models/tab_model.dart';
import '../providers/browser_provider.dart';

class TabBarWidget extends StatelessWidget {
  const TabBarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BrowserProvider>(
      builder: (context, provider, child) {
        return Container(
          height: DinoDimens.tabBarHeight,
          color: DinoColors.surfaceBg,
          child: Row(
            children: [
              // Tab list
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: DinoDimens.spacingSm,
                    vertical: 4,
                  ),
                  itemCount: provider.tabs.length,
                  itemBuilder: (context, index) {
                    final tab = provider.tabs[index];
                    final isActive = index == provider.currentTabIndex;
                    
                    return FadeInRight(
                      duration: const Duration(milliseconds: 200),
                      child: _TabItem(
                        tab: tab,
                        isActive: isActive,
                        onTap: () => provider.switchToTab(index),
                        onClose: () => provider.closeTab(index),
                      ),
                    );
                  },
                ),
              ),
              
              // Raptor Mode button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      onPressed: () {
                        // Navigate to Raptor Mode screen
                        Navigator.pushNamed(context, '/raptor');
                      },
                      icon: Icon(
                        Icons.shield_outlined,
                        color: provider.raptorModeEnabled
                            ? const Color(0xFF9D4EDD)
                            : DinoColors.textSecondary,
                        size: 20,
                      ),
                      tooltip: 'Raptor Mode - Private Browsing',
                      style: IconButton.styleFrom(
                        backgroundColor: provider.raptorModeEnabled
                            ? const Color(0xFF6A0DAD).withAlpha(30)
                            : DinoColors.glassWhite,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    // Proxy active badge
                    if (provider.proxyActive)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: DinoColors.cyberGreen,
                            shape: BoxShape.circle,
                            border: Border.all(color: DinoColors.surfaceBg, width: 1.5),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              // New tab button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: IconButton(
                  onPressed: () => provider.createNewTab(),
                  icon: const Icon(
                    Icons.add,
                    color: DinoColors.textSecondary,
                    size: 20,
                  ),
                  tooltip: 'New Tab',
                  style: IconButton.styleFrom(
                    backgroundColor: DinoColors.glassWhite,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TabItem extends StatelessWidget {
  final TabModel tab;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _TabItem({
    required this.tab,
    required this.isActive,
    required this.onTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        constraints: const BoxConstraints(
          minWidth: 100,
          maxWidth: 180,
        ),
        decoration: BoxDecoration(
          color: isActive ? DinoColors.cardBg : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? DinoColors.cyberGreen.withAlpha(100) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Loading indicator or favicon
            if (tab.isLoading)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isActive ? DinoColors.cyberGreen : DinoColors.textMuted,
                  ),
                ),
              )
            else
              Icon(
                Icons.public,
                size: 14,
                color: isActive ? DinoColors.cyberGreen : DinoColors.textMuted,
              ),
            
            const SizedBox(width: 8),
            
            // Title
            Expanded(
              child: Text(
                tab.displayTitle,
                style: TextStyle(
                  color: isActive ? DinoColors.textPrimary : DinoColors.textSecondary,
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            
            // Close button
            if (isActive)
              GestureDetector(
                behavior: HitTestBehavior.opaque, // Ensure tap is captured
                onTap: onClose,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: const Icon(
                    Icons.close,
                    size: 14,
                    color: DinoColors.textMuted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
