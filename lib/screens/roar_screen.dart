/// Roar Screen (Speed Dial)
/// 
/// Grid dashboard of frequently visited sites
/// with cached icons for instant loading
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/theme.dart';
import '../providers/browser_provider.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';

class RoarScreen extends StatefulWidget {
  const RoarScreen({super.key});
  @override
  State<RoarScreen> createState() => _RoarScreenState();
}

class _RoarScreenState extends State<RoarScreen> {
  final DatabaseService _db = DatabaseService();
  final AuthService _authService = AuthService();
  List<Map<String, dynamic>> _speedDial = [];
  bool _isLoading = true;
  
  String get _currentUserId => _authService.currentUser?.uid ?? 'anonymous';

  @override
  void initState() {
    super.initState();
    _loadSpeedDial();
  }

  Future<void> _loadSpeedDial() async {
    final sites = await _db.getSpeedDial(userId: _currentUserId);
    if (mounted) setState(() { _speedDial = sites; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DinoColors.darkBg,
      appBar: AppBar(
        backgroundColor: DinoColors.surfaceBg,
        title: const Row(children: [
          Icon(Icons.grid_view_rounded, color: DinoColors.amberOrange, size: 24),
          SizedBox(width: 8),
          Text('Roar! Speed Dial'),
        ]),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: DinoColors.cyberGreen))
          : _speedDial.isEmpty ? _buildEmptyState() : _buildGrid(),
    );
  }

  Widget _buildEmptyState() {
    return Center(child: FadeIn(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.speed, size: 80, color: DinoColors.textMuted.withAlpha(100)),
        const SizedBox(height: 16),
        Text('No Speed Dial Sites Yet', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: DinoColors.textMuted)),
        const SizedBox(height: 8),
        const Text('Visit sites to see them here', style: TextStyle(color: DinoColors.textMuted)),
      ],
    )));
  }

  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 1, crossAxisSpacing: 12, mainAxisSpacing: 12),
      itemCount: _speedDial.length,
      itemBuilder: (context, index) {
        final site = _speedDial[index];
        return FadeInUp(
          duration: Duration(milliseconds: 200 + index * 30),
          child: _SpeedDialTile(
            title: site['title'] ?? '',
            url: site['url'] ?? '',
            iconUrl: site['icon_url'],
            visitCount: site['visit_count'] ?? 0,
            onTap: () {
              context.read<BrowserProvider>().navigateTo(site['url']);
              Navigator.pop(context);
            },
          ),
        );
      },
    );
  }
}

class _SpeedDialTile extends StatelessWidget {
  final String title;
  final String url;
  final String? iconUrl;
  final int visitCount;
  final VoidCallback onTap;

  const _SpeedDialTile({required this.title, required this.url, this.iconUrl, required this.visitCount, required this.onTap});

  String get domain {
    try { return Uri.parse(url).host.replaceFirst('www.', ''); } catch (e) { return url; }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: DinoColors.cardBg,
          borderRadius: BorderRadius.circular(DinoDimens.radiusMedium),
          border: Border.all(color: DinoColors.glassBorder),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: DinoColors.surfaceBg, borderRadius: BorderRadius.circular(12)),
              child: iconUrl != null 
                  ? ClipRRect(borderRadius: BorderRadius.circular(12), child: CachedNetworkImage(imageUrl: iconUrl!, fit: BoxFit.cover, errorWidget: (_, __, ___) => _buildInitial()))
                  : _buildInitial(),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(title.isNotEmpty ? title : domain, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 2),
            Text('$visitCount visits', style: const TextStyle(fontSize: 10, color: DinoColors.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildInitial() {
    return Center(child: Text(domain.isNotEmpty ? domain[0].toUpperCase() : '?', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: DinoColors.cyberGreen)));
  }
}
