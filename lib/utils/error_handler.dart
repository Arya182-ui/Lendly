import 'package:flutter/material.dart';

/// Centralized error handler for the entire application
class AppErrorHandler {
  static final AppErrorHandler _instance = AppErrorHandler._internal();
  factory AppErrorHandler() => _instance;
  AppErrorHandler._internal();

  /// Convert any error to a user-friendly message
  static String getUserFriendlyMessage(dynamic error) {
    if (error == null) return 'An unexpected error occurred';

    String errorMessage = error.toString().toLowerCase();

    // Network errors
    if (errorMessage.contains('socketerror') ||
        errorMessage.contains('network') ||
        errorMessage.contains('connection')) {
      return 'No internet connection. Please check your network and try again.';
    }

    // Timeout errors
    if (errorMessage.contains('timeout') || errorMessage.contains('timed out')) {
      return 'Request timed out. Please try again.';
    }

    // Authentication errors
    if (errorMessage.contains('unauthorized') ||
        errorMessage.contains('401') ||
        errorMessage.contains('auth')) {
      return 'Session expired. Please login again.';
    }

    // Permission errors
    if (errorMessage.contains('forbidden') || errorMessage.contains('403')) {
      return 'You don\'t have permission to perform this action.';
    }

    // Not found errors
    if (errorMessage.contains('not found') || errorMessage.contains('404')) {
      return 'The requested resource was not found.';
    }

    // Server errors
    if (errorMessage.contains('500') ||
        errorMessage.contains('server error') ||
        errorMessage.contains('internal server')) {
      return 'Server error. Please try again later.';
    }

    // Rate limiting
    if (errorMessage.contains('too many requests') ||
        errorMessage.contains('rate limit')) {
      return 'Too many requests. Please wait a moment and try again.';
    }

    // Validation errors
    if (errorMessage.contains('validation') || errorMessage.contains('invalid')) {
      return 'Invalid input. Please check your information and try again.';
    }

    // File upload errors
    if (errorMessage.contains('file') && errorMessage.contains('large')) {
      return 'File is too large. Please choose a smaller file.';
    }

    // Firebase specific errors
    if (errorMessage.contains('firebase')) {
      if (errorMessage.contains('index')) {
        return 'Database configuration issue. Please contact support.';
      }
      if (errorMessage.contains('permission denied')) {
        return 'Access denied. Please check your permissions.';
      }
    }

    // Default message for unknown errors
    return 'Something went wrong. Please try again.';
  }

  /// Show error dialog
  static void showErrorDialog(BuildContext context, dynamic error) {
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Error'),
          ],
        ),
        content: Text(getUserFriendlyMessage(error)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show error snackbar
  static void showErrorSnackbar(BuildContext context, dynamic error) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(getUserFriendlyMessage(error)),
            ),
          ],
        ),
        backgroundColor: Colors.red[700],
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Show success message
  static void showSuccess(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green[700],
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show info message
  static void showInfo(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blue[700],
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
