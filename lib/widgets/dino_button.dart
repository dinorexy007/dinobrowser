/// Dino Button Widget
/// 
/// Themed button with glassmorphism and micro-animations
library;

import 'package:flutter/material.dart';
import 'dart:ui';
import '../config/theme.dart';

/// Primary action button with gradient background
class DinoButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final double? width;

  const DinoButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.width,
  });

  @override
  State<DinoButton> createState() => _DinoButtonState();
}

class _DinoButtonState extends State<DinoButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onPressed == null) return;
    setState(() => _isPressed = true);
    _animationController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onPressed == null) return;
    setState(() => _isPressed = false);
    _animationController.reverse();
  }

  void _onTapCancel() {
    if (widget.onPressed == null) return;
    setState(() => _isPressed = false);
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.isLoading ? null : widget.onPressed,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: Container(
          width: widget.width,
          padding: const EdgeInsets.symmetric(
            horizontal: DinoDimens.spacingLg,
            vertical: DinoDimens.spacingMd,
          ),
          decoration: BoxDecoration(
            gradient: widget.isOutlined ? null : DinoGradients.primaryGradient,
            borderRadius: BorderRadius.circular(DinoDimens.radiusMedium),
            border: widget.isOutlined
                ? Border.all(color: DinoColors.cyberGreen, width: 2)
                : null,
            boxShadow: widget.isOutlined
                ? null
                : [
                    BoxShadow(
                      color: DinoColors.cyberGreen.withAlpha(_isPressed ? 80 : 50),
                      blurRadius: _isPressed ? 16 : 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.isLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      DinoColors.deepJungle,
                    ),
                  ),
                )
              else if (widget.icon != null)
                Icon(
                  widget.icon,
                  color: widget.isOutlined
                      ? DinoColors.cyberGreen
                      : DinoColors.deepJungle,
                  size: 18,
                ),
              if ((widget.icon != null || widget.isLoading) &&
                  widget.label.isNotEmpty)
                const SizedBox(width: DinoDimens.spacingSm),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.isOutlined
                      ? DinoColors.cyberGreen
                      : DinoColors.deepJungle,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Glass-style icon button for toolbars
class DinoIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool isActive;
  final Color? activeColor;
  final double size;

  const DinoIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.isActive = false,
    this.activeColor,
    this.size = 44,
  });

  @override
  State<DinoIconButton> createState() => _DinoIconButtonState();
}

class _DinoIconButtonState extends State<DinoIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.activeColor ?? DinoColors.cyberGreen;
    
    return Tooltip(
      message: widget.tooltip ?? '',
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.isActive
                  ? activeColor.withAlpha(30)
                  : (_isHovered ? DinoColors.glassWhite : Colors.transparent),
              borderRadius: BorderRadius.circular(DinoDimens.radiusMedium),
              border: Border.all(
                color: widget.isActive
                    ? activeColor.withAlpha(80)
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Icon(
              widget.icon,
              color: widget.isActive
                  ? activeColor
                  : (_isHovered
                      ? DinoColors.textPrimary
                      : DinoColors.textSecondary),
              size: widget.size * 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

/// Glass effect card container
class DinoGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final VoidCallback? onTap;

  const DinoGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = DinoDimens.radiusLarge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: margin,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: DinoColors.glassBorder,
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: padding ?? const EdgeInsets.all(DinoDimens.spacingMd),
              decoration: BoxDecoration(
                gradient: DinoGradients.glassGradient,
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
