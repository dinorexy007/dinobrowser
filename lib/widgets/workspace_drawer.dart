/// Workspace Drawer Widget
/// 
/// Sidebar drawer for switching between contextual workspaces
/// (Study, Coding, Entertainment, etc.)
/// Now includes user authentication section and feature gating
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import '../config/theme.dart';
import '../models/workspace_model.dart';
import '../providers/browser_provider.dart';
import '../providers/auth_provider.dart';

class WorkspaceDrawer extends StatelessWidget {
  const WorkspaceDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<BrowserProvider, AuthProvider>(
      builder: (context, browserProvider, authProvider, child) {
        return Drawer(
          backgroundColor: DinoColors.surfaceBg,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with user profile
                _buildHeader(context, authProvider, browserProvider),
                
                // Workspaces label
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DinoDimens.spacingMd,
                    DinoDimens.spacingLg,
                    DinoDimens.spacingMd,
                    DinoDimens.spacingSm,
                  ),
                  child: Text(
                    'SWITCH WORKSPACE',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: DinoColors.textMuted,
                      letterSpacing: 1.2,
                      fontSize: 11,
                    ),
                  ),
                ),
                
                // Workspace list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DinoDimens.spacingSm,
                    ),
                    itemCount: browserProvider.workspaces.length,
                    itemBuilder: (context, index) {
                      final workspace = browserProvider.workspaces[index];
                      final isActive = workspace.id == browserProvider.currentWorkspace.id;
                      
                      return FadeInLeft(
                        duration: Duration(milliseconds: 200 + (index * 50)),
                        child: _WorkspaceItem(
                          workspace: workspace,
                          isActive: isActive,
                          onTap: () async {
                            await browserProvider.switchWorkspace(workspace);
                            if (context.mounted) Navigator.pop(context);
                          },
                        ),
                      );
                    },
                  ),
                ),
                
                // Footer actions
                _buildFooterActions(context, authProvider),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, AuthProvider authProvider, BrowserProvider browserProvider) {
    return Container(
      padding: const EdgeInsets.all(DinoDimens.spacingLg),
      decoration: const BoxDecoration(
        gradient: DinoGradients.darkGradient,
        border: Border(
          bottom: BorderSide(
            color: DinoColors.glassBorder,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Dino icon placeholder
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: DinoGradients.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.pets,
                  color: DinoColors.deepJungle,
                  size: 28,
                ),
              ),
              const SizedBox(width: DinoDimens.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DINO',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: DinoColors.cyberGreen,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),
                    Text(
                      'Browser',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: DinoDimens.spacingMd),
          
          // User section
          if (authProvider.isLoggedIn)
            _buildUserProfile(context, authProvider, browserProvider)
          else
            _buildSignInPrompt(context),
        ],
      ),
    );
  }

  Widget _buildUserProfile(BuildContext context, AuthProvider authProvider, BrowserProvider browserProvider) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DinoColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DinoColors.glassBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [DinoColors.raptorPurple, DinoColors.pterodactylBlue],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                authProvider.displayName.isNotEmpty 
                    ? authProvider.displayName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  authProvider.displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: DinoColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  authProvider.email ?? '',
                  style: const TextStyle(
                    fontSize: 11,
                    color: DinoColors.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: DinoColors.textMuted, size: 20),
            color: DinoColors.cardBg,
            onSelected: (value) async {
              if (value == 'signout') {
                // Clear browser session first
                await browserProvider.clearUserSession();
                // Then sign out
                await authProvider.signOut();
                // Close the drawer
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'signout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18, color: DinoColors.error),
                    SizedBox(width: 8),
                    Text('Sign Out', style: TextStyle(color: DinoColors.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSignInPrompt(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        Navigator.pushNamed(context, '/auth');
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              DinoColors.cyberGreen.withAlpha(30),
              DinoColors.raptorPurple.withAlpha(30),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: DinoColors.cyberGreen.withAlpha(50)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: DinoColors.cyberGreen.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.person_add,
                color: DinoColors.cyberGreen,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sign In',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: DinoColors.cyberGreen,
                    ),
                  ),
                  Text(
                    'Unlock premium features',
                    style: TextStyle(
                      fontSize: 11,
                      color: DinoColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: DinoColors.cyberGreen,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterActions(BuildContext context, AuthProvider authProvider) {
    return Container(
      padding: const EdgeInsets.all(DinoDimens.spacingMd),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(
            color: DinoColors.glassBorder,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          _DrawerAction(
            icon: Icons.history,
            label: 'Time-Travel History',
            color: DinoColors.pterodactylBlue,
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/history');
            },
          ),
          const SizedBox(height: 8),
          
          // Fossil Pages - gated
          _DrawerAction(
            icon: Icons.download_done,
            label: 'Fossil Pages',
            color: DinoColors.amberOrange,
            isLocked: !authProvider.isLoggedIn,
            onTap: () {
              Navigator.pop(context);
              if (authProvider.isLoggedIn) {
                Navigator.pushNamed(context, '/fossils');
              } else {
                _showLockedFeatureDialog(context, 'Fossil Pages');
              }
            },
          ),
          const SizedBox(height: 8),
          
          // Extensions - gated
          _DrawerAction(
            icon: Icons.extension,
            label: 'Extension Store',
            color: DinoColors.raptorPurple,
            isLocked: !authProvider.isLoggedIn,
            onTap: () {
              Navigator.pop(context);
              if (authProvider.isLoggedIn) {
                Navigator.pushNamed(context, '/extensions');
              } else {
                _showLockedFeatureDialog(context, 'Extension Store');
              }
            },
          ),
          const SizedBox(height: 8),
          _DrawerAction(
            icon: Icons.grid_view_rounded,
            label: 'Roar (Speed Dial)',
            color: DinoColors.amberOrange,
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/roar');
            },
          ),
          const SizedBox(height: 8),
          _DrawerAction(
            icon: Icons.settings,
            label: 'Settings',
            color: DinoColors.textSecondary,
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
      ),
    );
  }

  void _showLockedFeatureDialog(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DinoColors.surfaceBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: DinoColors.cyberGreen.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.lock, color: DinoColors.cyberGreen),
            ),
            const SizedBox(width: 12),
            const Text('Premium Feature'),
          ],
        ),
        content: Text(
          'Create an account to access $feature and other premium features like workspaces, extensions, and offline reading.',
          style: const TextStyle(color: DinoColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later', style: TextStyle(color: DinoColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/auth');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: DinoColors.cyberGreen,
              foregroundColor: DinoColors.deepJungle,
            ),
            child: const Text('Create Account'),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceItem extends StatelessWidget {
  final WorkspaceModel workspace;
  final bool isActive;
  final VoidCallback onTap;

  const _WorkspaceItem({
    required this.workspace,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(
          horizontal: DinoDimens.spacingMd,
          vertical: DinoDimens.spacingSm + 4,
        ),
        decoration: BoxDecoration(
          color: isActive 
              ? workspace.color.withAlpha(30)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(DinoDimens.radiusMedium),
          border: Border.all(
            color: isActive 
                ? workspace.color.withAlpha(100)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            // Workspace icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: workspace.color.withAlpha(isActive ? 50 : 30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                workspace.icon,
                color: workspace.color,
                size: 22,
              ),
            ),
            const SizedBox(width: DinoDimens.spacingMd),
            
            // Workspace name
            Expanded(
              child: Text(
                workspace.name,
                style: TextStyle(
                  color: isActive 
                      ? DinoColors.textPrimary
                      : DinoColors.textSecondary,
                  fontWeight: isActive 
                      ? FontWeight.w600 
                      : FontWeight.normal,
                  fontSize: 15,
                ),
              ),
            ),
            
            // Active indicator
            if (isActive)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: workspace.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: workspace.color.withAlpha(150),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DrawerAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isLocked;

  const _DrawerAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DinoDimens.radiusMedium),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DinoDimens.spacingSm,
          vertical: DinoDimens.spacingSm,
        ),
        child: Row(
          children: [
            Icon(icon, color: isLocked ? DinoColors.textMuted : color, size: 22),
            const SizedBox(width: DinoDimens.spacingMd),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isLocked ? DinoColors.textMuted : DinoColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
            if (isLocked)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: DinoColors.cyberGreen.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock, size: 12, color: DinoColors.cyberGreen),
                    SizedBox(width: 4),
                    Text(
                      'PRO',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: DinoColors.cyberGreen,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
