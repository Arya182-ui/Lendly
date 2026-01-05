import 'package:flutter/material.dart';

/// Error types for better error handling
enum AppErrorType {
  network,
  timeout,
  server,
  unauthorized,
  notFound,
  validation,
  unknown,
}

/// App-wide error class
class AppError {
  final AppErrorType type;
  final String message;
  final String? details;
  final int? statusCode;
  final dynamic originalError;

  AppError({
    required this.type,
    required this.message,
    this.details,
    this.statusCode,
    this.originalError,
  });

  factory AppError.fromStatusCode(int statusCode, [String? message]) {
    switch (statusCode) {
      case 400:
        return AppError(
          type: AppErrorType.validation,
          message: message ?? 'Invalid request',
          statusCode: statusCode,
        );
      case 401:
        return AppError(
          type: AppErrorType.unauthorized,
          message: message ?? 'Please login again',
          statusCode: statusCode,
        );
      case 404:
        return AppError(
          type: AppErrorType.notFound,
          message: message ?? 'Resource not found',
          statusCode: statusCode,
        );
      case 408:
        return AppError(
          type: AppErrorType.timeout,
          message: message ?? 'Request timed out',
          statusCode: statusCode,
        );
      case 500:
      case 502:
      case 503:
        return AppError(
          type: AppErrorType.server,
          message: message ?? 'Server error. Please try again later.',
          statusCode: statusCode,
        );
      default:
        return AppError(
          type: AppErrorType.unknown,
          message: message ?? 'Something went wrong',
          statusCode: statusCode,
        );
    }
  }

  factory AppError.network([String? message]) {
    return AppError(
      type: AppErrorType.network,
      message: message ?? 'No internet connection',
    );
  }

  factory AppError.timeout([String? message]) {
    return AppError(
      type: AppErrorType.timeout,
      message: message ?? 'Request timed out. Please try again.',
    );
  }

  IconData get icon {
    switch (type) {
      case AppErrorType.network:
        return Icons.wifi_off;
      case AppErrorType.timeout:
        return Icons.access_time;
      case AppErrorType.server:
        return Icons.cloud_off;
      case AppErrorType.unauthorized:
        return Icons.lock;
      case AppErrorType.notFound:
        return Icons.search_off;
      case AppErrorType.validation:
        return Icons.warning;
      case AppErrorType.unknown:
        return Icons.error_outline;
    }
  }

  Color get color {
    switch (type) {
      case AppErrorType.network:
      case AppErrorType.timeout:
        return Colors.orange;
      case AppErrorType.server:
      case AppErrorType.unauthorized:
        return Colors.red;
      case AppErrorType.notFound:
        return Colors.grey;
      case AppErrorType.validation:
        return Colors.amber;
      case AppErrorType.unknown:
        return Colors.red;
    }
  }

  bool get canRetry {
    return type == AppErrorType.network || 
           type == AppErrorType.timeout || 
           type == AppErrorType.server;
  }
}

/// Error display widget
class ErrorDisplay extends StatelessWidget {
  final AppError error;
  final VoidCallback? onRetry;
  final bool compact;

  const ErrorDisplay({
    super.key,
    required this.error,
    this.onRetry,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _buildCompact(context);
    }
    return _buildFull(context);
  }

  Widget _buildCompact(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: error.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: error.color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(error.icon, color: error.color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error.message,
              style: TextStyle(
                color: error.color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (error.canRetry && onRetry != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              color: error.color,
              onPressed: onRetry,
            ),
        ],
      ),
    );
  }

  Widget _buildFull(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: error.color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                error.icon,
                size: 48,
                color: error.color,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _getTitle(),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              error.message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            if (error.details != null) ...[
              const SizedBox(height: 8),
              Text(
                error.details!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            if (error.canRetry && onRetry != null)
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getTitle() {
    switch (error.type) {
      case AppErrorType.network:
        return 'No Connection';
      case AppErrorType.timeout:
        return 'Request Timeout';
      case AppErrorType.server:
        return 'Server Error';
      case AppErrorType.unauthorized:
        return 'Session Expired';
      case AppErrorType.notFound:
        return 'Not Found';
      case AppErrorType.validation:
        return 'Invalid Data';
      case AppErrorType.unknown:
        return 'Something Went Wrong';
    }
  }
}

/// Network error banner
class NetworkErrorBanner extends StatelessWidget {
  final VoidCallback? onRetry;

  const NetworkErrorBanner({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: Colors.orange[700],
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            const Icon(Icons.wifi_off, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'No internet connection',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                child: const Text(
                  'Retry',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Empty state widget
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Loading state widget
class LoadingWidget extends StatelessWidget {
  final String? message;
  final bool compact;

  const LoadingWidget({
    super.key,
    this.message,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          if (message != null) ...[
            const SizedBox(width: 12),
            Text(message!, style: const TextStyle(fontSize: 14)),
          ],
        ],
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Async data wrapper for loading/error/data states
class AsyncDataWidget<T> extends StatelessWidget {
  final bool isLoading;
  final AppError? error;
  final T? data;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;
  final Widget? loadingWidget;
  final String? loadingMessage;
  final Widget? emptyWidget;

  const AsyncDataWidget({
    super.key,
    required this.isLoading,
    this.error,
    this.data,
    required this.builder,
    this.onRetry,
    this.loadingWidget,
    this.loadingMessage,
    this.emptyWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return loadingWidget ?? LoadingWidget(message: loadingMessage);
    }

    if (error != null) {
      return ErrorDisplay(error: error!, onRetry: onRetry);
    }

    if (data == null) {
      return emptyWidget ?? const EmptyStateWidget(
        icon: Icons.inbox,
        title: 'No Data',
        message: 'Nothing to show here',
      );
    }

    return builder(data as T);
  }
}
