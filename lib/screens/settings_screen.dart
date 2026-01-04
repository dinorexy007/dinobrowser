/// Settings Screen
/// 
/// Application settings and shortcuts

import 'package:flutter/material.dart';
import '../config/theme.dart';
import 'downloads_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DinoColors.darkBg,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: DinoColors.surfaceBg,
        elevation: 0,
      ),
      body: ListView(
        children: [
          // Bookmarks Section
          _buildHeading('GENERAL'),
          
          ListTile(
            leading: const Icon(Icons.bookmark, color: DinoColors.cyberGreen),
            title: const Text(
              'Bookmarks',
              style: TextStyle(color: DinoColors.textPrimary),
            ),
            subtitle: const Text(
              'View and manage saved pages',
              style: TextStyle(color: DinoColors.textMuted),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: DinoColors.textMuted),
            onTap: () {
              Navigator.pushNamed(context, '/bookmarks');
            },
          ),
          
          const Divider(color: DinoColors.glassBorder),
          
          ListTile(
            leading: const Icon(Icons.download, color: DinoColors.cyberGreen),
            title: const Text(
              'Downloads',
              style: TextStyle(color: DinoColors.textPrimary),
            ),
            subtitle: const Text(
              'Manage downloaded files',
              style: TextStyle(color: DinoColors.textMuted),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: DinoColors.textMuted),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DownloadsScreen()),
              );
            },
          ),
          
          const Divider(color: DinoColors.glassBorder),
          
          // Browser Settings
          _buildHeading('BROWSER'),
          
          ListTile(
            leading: const Icon(Icons.privacy_tip, color: DinoColors.textSecondary),
            title: const Text(
              'Privacy & Security',
              style: TextStyle(color: DinoColors.textPrimary),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: DinoColors.textMuted),
            onTap: () {
              // TODO: Implement privacy settings
            },
          ),
          
          ListTile(
            leading: const Icon(Icons.palette, color: DinoColors.textSecondary),
            title: const Text(
              'Appearance',
              style: TextStyle(color: DinoColors.textPrimary),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: DinoColors.textMuted),
            onTap: () {
              // TODO: Implement appearance settings
            },
          ),
          
          const Divider(color: DinoColors.glassBorder),
          
          // About
          _buildHeading('SUPPORT'),
          
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: DinoColors.cyberGreen.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.feedback, color: DinoColors.cyberGreen),
            ),
            title: const Text(
              'Send Feedback',
              style: TextStyle(color: DinoColors.textPrimary),
            ),
            subtitle: const Text(
              'Help us improve DINO Browser',
              style: TextStyle(color: DinoColors.textMuted),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: DinoColors.textMuted),
            onTap: () {
              Navigator.pushNamed(context, '/feedback');
            },
          ),
          
          ListTile(
            leading: const Icon(Icons.info, color: DinoColors.textSecondary),
            title: const Text(
              'About DINO Browser',
              style: TextStyle(color: DinoColors.textPrimary),
            ),
            subtitle: const Text(
              'Version 1.0.0 (Early Access)',
              style: TextStyle(color: DinoColors.textMuted),
            ),
            onTap: () {},
          ),
        ],
      ),
    );
  }
  
  Widget _buildHeading(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        text,
        style: const TextStyle(
          color: DinoColors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
