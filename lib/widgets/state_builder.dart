import 'package:flutter/material.dart';

/// State management for loading, error, and empty states
enum ViewState {
  loading,
  loaded,
  error,
  empty,
}

/// Universal state widget for handling loading, error, and empty states
class StateBuilder extends StatelessWidget {
  final ViewState state;
  final dynamic error;
  final VoidCallback? onRetry;
  final Widget child;
  final String? emptyMessage;
  final String? emptyIcon;
  final Widget? loadingWidget;
  final Widget? errorWidget;
  final Widget? emptyWidget;

  const StateBuilder({
    super.key,
    required this.state,
    required this.child,
    this.error,
    this.onRetry,
    this.emptyMessage,
    this.emptyIcon,
    this.loadingWidget,
    this.errorWidget,
    this.emptyWidget,
  });

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case ViewState.loading:
        return loadingWidget ?? const LoadingView();

      case ViewState.error:
        return errorWidget ??
            ErrorView(
              error: error,
              onRetry: onRetry,
            );

      case ViewState.empty:
        return emptyWidget ??
            EmptyView(
              message: emptyMessage ?? 'No items found',
              icon: emptyIcon,
              onRetry: onRetry,
            );

      case ViewState.loaded:
        return child;
    }
  }
}

/// Loading view widget
class LoadingView extends StatelessWidget {
  final String? message;
  final bool showMessage;

  const LoadingView({
    super.key,
    this.message,
    this.showMessage = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          if (showMessage && message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// Error view widget with retry option
class ErrorView extends StatelessWidget {
  final dynamic error;
  final VoidCallback? onRetry;
  final String? customMessage;

  const ErrorView({
    super.key,
    required this.error,
    this.onRetry,
    this.customMessage,
  });

  String _getErrorMessage() {
    if (customMessage != null) return customMessage!;

    String errorStr = error.toString().toLowerCase();

    if (errorStr.contains('network') ||
        errorStr.contains('socket') ||
        errorStr.contains('connection')) {
      return 'No internet connection';
    }

    if (errorStr.contains('timeout')) {
      return 'Request timed out';
    }

    if (errorStr.contains('unauthorized') || errorStr.contains('401')) {
      return 'Session expired';
    }

    if (errorStr.contains('404') || errorStr.contains('not found')) {
      return 'Resource not found';
    }

    if (errorStr.contains('500') || errorStr.contains('server')) {
      return 'Server error';
    }

    return 'Something went wrong';
  }

  IconData _getErrorIcon() {
    String errorStr = error.toString().toLowerCase();

    if (errorStr.contains('network') ||
        errorStr.contains('socket') ||
        errorStr.contains('connection')) {
      return Icons.wifi_off;
    }

    if (errorStr.contains('timeout')) {
      return Icons.timer_off;
    }

    if (errorStr.contains('unauthorized')) {
      return Icons.lock_outline;
    }

    return Icons.error_outline;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getErrorIcon(),
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _getErrorMessage(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Please try again',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Empty state view widget
class EmptyView extends StatelessWidget {
  final String message;
  final String? icon;
  final VoidCallback? onRetry;
  final String? actionLabel;

  const EmptyView({
    super.key,
    required this.message,
    this.icon,
    this.onRetry,
    this.actionLabel,
  });

  IconData _getIcon() {
    switch (icon?.toLowerCase()) {
      case 'search':
        return Icons.search_off;
      case 'items':
        return Icons.inventory_2_outlined;
      case 'groups':
        return Icons.group_outlined;
      case 'chat':
        return Icons.chat_bubble_outline;
      case 'notifications':
        return Icons.notifications_none;
      case 'friends':
        return Icons.people_outline;
      default:
        return Icons.inbox_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getIcon(),
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(actionLabel ?? 'Refresh'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shimmer loading placeholder
class ShimmerLoading extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const ShimmerLoading({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment(-1.0 - _controller.value * 2, 0.0),
              end: Alignment(1.0 - _controller.value * 2, 0.0),
              colors: [
                Colors.grey[300]!,
                Colors.grey[200]!,
                Colors.grey[300]!,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// List shimmer placeholder
class ListShimmer extends StatelessWidget {
  final int itemCount;

  const ListShimmer({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: itemCount,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ShimmerLoading(
                width: 60,
                height: 60,
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerLoading(
                      width: double.infinity,
                      height: 16,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 8),
                    ShimmerLoading(
                      width: MediaQuery.of(context).size.width * 0.6,
                      height: 14,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 8),
                    ShimmerLoading(
                      width: MediaQuery.of(context).size.width * 0.4,
                      height: 14,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
