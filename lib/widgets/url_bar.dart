/// URL Bar Widget
/// 
/// Modern address bar with search suggestions,
/// protocol display, and action buttons
library;

import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../config/theme.dart';

class UrlBar extends StatefulWidget {
  final String currentUrl;
  final bool isLoading;
  final double progress;
  final Function(String url) onSubmitted;
  final VoidCallback? onReload;
  final VoidCallback? onStop;
  final VoidCallback? onBookmark;
  final bool isBookmarked;

  const UrlBar({
    super.key,
    this.currentUrl = '',
    this.isLoading = false,
    this.progress = 0.0,
    required this.onSubmitted,
    this.onReload,
    this.onStop,
    this.onBookmark,
    this.isBookmarked = false,
  });

  @override
  State<UrlBar> createState() => _UrlBarState();
}

class _UrlBarState extends State<UrlBar> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _isFocused = false;
  bool _showSearchIcon = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _getDisplayUrl());
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(UrlBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isFocused && oldWidget.currentUrl != widget.currentUrl) {
      _controller.text = _getDisplayUrl();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
      if (_isFocused) {
        _controller.text = widget.currentUrl;
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
        _showSearchIcon = false;
      } else {
        _controller.text = _getDisplayUrl();
        _showSearchIcon = true;
      }
    });
  }

  String _getDisplayUrl() {
    if (widget.currentUrl.isEmpty || widget.currentUrl == 'about:blank') {
      return '';
    }
    // Remove protocol for cleaner display
    return widget.currentUrl
        .replaceFirst('https://', '')
        .replaceFirst('http://', '')
        .replaceFirst('www.', '');
  }

  bool get _isSecure => widget.currentUrl.startsWith('https://');

  @override
  Widget build(BuildContext context) {
    return Container(
      height: DinoDimens.urlBarHeight,
      margin: const EdgeInsets.symmetric(
        horizontal: DinoDimens.spacingMd,
        vertical: DinoDimens.spacingSm,
      ),
      decoration: BoxDecoration(
        color: DinoColors.cardBg,
        borderRadius: BorderRadius.circular(DinoDimens.radiusLarge),
        border: Border.all(
          color: _isFocused ? DinoColors.cyberGreen : DinoColors.glassBorder,
          width: _isFocused ? 2 : 1,
        ),
        boxShadow: _isFocused
            ? [
                BoxShadow(
                  color: DinoColors.cyberGreen.withAlpha(50),
                  blurRadius: 12,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // Search/Lock icon
          Padding(
            padding: const EdgeInsets.only(left: DinoDimens.spacingMd),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _showSearchIcon
                  ? Icon(
                      widget.currentUrl.isNotEmpty && !_isFocused
                          ? (_isSecure ? Icons.lock_outlined : Icons.lock_open)
                          : Icons.search,
                      color: widget.currentUrl.isNotEmpty && _isSecure
                          ? DinoColors.cyberGreen
                          : DinoColors.textMuted,
                      size: 18,
                      key: const ValueKey('search'),
                    )
                  : const Icon(
                      Icons.search,
                      color: DinoColors.textMuted,
                      size: 18,
                      key: ValueKey('editing'),
                    ),
            ),
          ),
          
          // URL input
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              style: const TextStyle(
                color: DinoColors.textPrimary,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Search or enter URL',
                hintStyle: TextStyle(
                  color: DinoColors.textMuted.withAlpha(150),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: DinoDimens.spacingSm,
                ),
              ),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              autocorrect: false,
              onSubmitted: (value) {
                widget.onSubmitted(value.trim());
                _focusNode.unfocus();
              },
            ),
          ),
          
          // Action buttons
          if (!_isFocused) ...[
            // Bookmark button
            if (widget.onBookmark != null && widget.currentUrl.isNotEmpty)
              FadeInRight(
                duration: const Duration(milliseconds: 200),
                child: IconButton(
                  icon: Icon(
                    widget.isBookmarked
                        ? Icons.bookmark
                        : Icons.bookmark_border,
                    color: widget.isBookmarked
                        ? DinoColors.cyberGreen
                        : DinoColors.textMuted,
                    size: 20,
                  ),
                  onPressed: widget.onBookmark,
                  tooltip: 'Bookmark',
                ),
              ),
            
            // Reload/Stop button
            if (widget.isLoading)
              IconButton(
                icon: const Icon(
                  Icons.close,
                  color: DinoColors.textMuted,
                  size: 20,
                ),
                onPressed: widget.onStop,
                tooltip: 'Stop',
              )
            else if (widget.currentUrl.isNotEmpty)
              IconButton(
                icon: const Icon(
                  Icons.refresh,
                  color: DinoColors.textMuted,
                  size: 20,
                ),
                onPressed: widget.onReload,
                tooltip: 'Reload',
              ),
          ],
          
          // Clear button when focused
          if (_isFocused && _controller.text.isNotEmpty)
            FadeInRight(
              duration: const Duration(milliseconds: 150),
              child: IconButton(
                icon: const Icon(
                  Icons.clear,
                  color: DinoColors.textMuted,
                  size: 18,
                ),
                onPressed: () {
                  _controller.clear();
                  setState(() {});
                },
              ),
            ),
          
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}
