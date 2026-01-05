import 'package:flutter/material.dart';

/// Global loading overlay manager
class LoadingOverlay {
  static OverlayEntry? _currentOverlay;

  /// Show loading overlay
  static void show(
    BuildContext context, {
    String? message,
    bool dismissible = false,
  }) {
    hide(); // Remove any existing overlay

    _currentOverlay = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Semi-transparent background
          GestureDetector(
            onTap: dismissible ? () => hide() : null,
            child: Container(
              color: Colors.black54,
            ),
          ),
          // Loading indicator
          Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    if (message != null) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: 200,
                        child: Text(
                          message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_currentOverlay!);
  }

  /// Hide loading overlay
  static void hide() {
    _currentOverlay?.remove();
    _currentOverlay = null;
  }
}

/// Loading button that shows spinner when loading
class LoadingButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool isOutlined;
  final Color? backgroundColor;
  final Color? textColor;

  const LoadingButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.isOutlined = false,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final button = isOutlined
        ? OutlinedButton(
            onPressed: isLoading ? null : onPressed,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 16,
              ),
            ),
            child: _buildContent(),
          )
        : ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: backgroundColor,
              foregroundColor: textColor,
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 16,
              ),
            ),
            child: _buildContent(),
          );

    return button;
  }

  Widget _buildContent() {
    if (isLoading) {
      return const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(label),
        ],
      );
    }

    return Text(label);
  }
}

/// Pull to refresh wrapper
class PullToRefreshWrapper extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
  final String? refreshText;

  const PullToRefreshWrapper({
    super.key,
    required this.onRefresh,
    required this.child,
    this.refreshText,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: child,
    );
  }
}

/// Retry widget for failed operations
class RetryWidget extends StatelessWidget {
  final String? message;
  final VoidCallback onRetry;
  final bool isLoading;

  const RetryWidget({
    super.key,
    this.message,
    required this.onRetry,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.refresh,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message ?? 'Tap to retry',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 16),
          LoadingButton(
            label: 'Retry',
            onPressed: onRetry,
            isLoading: isLoading,
            icon: Icons.refresh,
          ),
        ],
      ),
    );
  }
}
