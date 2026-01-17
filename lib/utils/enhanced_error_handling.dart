/// Enhanced Error Handling for Backend Security Integration
/// Handles new error codes from the secure backend
import 'package:flutter/material.dart';

/// Enhanced API Error Codes from the backend
class ApiErrorCodes {
  // Authentication errors
  static const String authTokenMissing = 'AUTH_TOKEN_MISSING';
  static const String authTokenExpired = 'AUTH_TOKEN_EXPIRED';
  static const String authTokenRevoked = 'AUTH_TOKEN_REVOKED';
  static const String authTokenMalformed = 'AUTH_TOKEN_MALFORMED';
  static const String authTokenInvalidFormat = 'AUTH_TOKEN_INVALID_FORMAT';
  
  // Rate limiting errors
  static const String rateLimitExceeded = 'RATE_LIMIT_EXCEEDED';
  static const String tooManyRequests = 'TOO_MANY_REQUESTS';
  
  // File upload errors
  static const String fileTooLarge = 'FILE_TOO_LARGE';
  static const String invalidFileType = 'INVALID_FILE_TYPE';
  static const String uploadError = 'FILE_UPLOAD_ERROR';
  
  // Validation errors
  static const String validationFailed = 'VALIDATION_FAILED';
  static const String invalidInput = 'INVALID_INPUT';
  static const String suspiciousActivity = 'SUSPICIOUS_ACTIVITY';
  
  // Server errors
  static const String internalError = 'INTERNAL_ERROR';
  static const String serviceUnavailable = 'SERVICE_UNAVAILABLE';
  static const String authenticationFailed = 'AUTHENTICATION_FAILED';
}

/// Enhanced Error Model with security context
class ApiError {
  final String message;
  final String? code;
  final int? statusCode;
  final Map<String, dynamic>? details;
  final bool isRetryable;
  final bool requiresTokenRefresh;
  final bool requiresReauth;
  final DateTime timestamp;

  ApiError({
    required this.message,
    this.code,
    this.statusCode,
    this.details,
    this.isRetryable = false,
    this.requiresTokenRefresh = false,
    this.requiresReauth = false,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create error from API response
  factory ApiError.fromResponse(Map<String, dynamic> response, int statusCode) {
    final code = response['code'] as String?;
    final message = response['error'] as String? ?? 'Unknown error';
    final details = response['details'] as Map<String, dynamic>?;
    
    // Determine error handling strategy based on code
    bool isRetryable = false;
    bool requiresTokenRefresh = false;
    bool requiresReauth = false;
    
    switch (code) {
      case ApiErrorCodes.authTokenExpired:
        requiresTokenRefresh = true;
        isRetryable = true;
        break;
      case ApiErrorCodes.authTokenRevoked:
      case ApiErrorCodes.authTokenMalformed:
      case ApiErrorCodes.authTokenInvalidFormat:
        requiresReauth = true;
        break;
      case ApiErrorCodes.rateLimitExceeded:
      case ApiErrorCodes.tooManyRequests:
        isRetryable = true; // With exponential backoff
        break;
      case ApiErrorCodes.serviceUnavailable:
      case ApiErrorCodes.internalError:
        isRetryable = true;
        break;
    }
    
    return ApiError(
      message: message,
      code: code,
      statusCode: statusCode,
      details: details,
      isRetryable: isRetryable,
      requiresTokenRefresh: requiresTokenRefresh,
      requiresReauth: requiresReauth,
    );
  }

  /// Get user-friendly error message
  String get userMessage {
    switch (code) {
      case ApiErrorCodes.authTokenExpired:
        return 'Your session has expired. Please wait while we refresh it.';
      case ApiErrorCodes.authTokenRevoked:
      case ApiErrorCodes.authenticationFailed:
        return 'Please sign in again to continue.';
      case ApiErrorCodes.rateLimitExceeded:
      case ApiErrorCodes.tooManyRequests:
        final retryAfter = details?['retryAfter'] as int?;
        return retryAfter != null 
          ? 'Too many requests. Please wait ${retryAfter}s before trying again.'
          : 'Too many requests. Please wait a moment before trying again.';
      case ApiErrorCodes.fileTooLarge:
        return 'File is too large. Please choose a smaller file (max 5MB).';
      case ApiErrorCodes.invalidFileType:
        return 'Invalid file type. Please upload only images or PDF files.';
      case ApiErrorCodes.validationFailed:
        return details?['message'] as String? ?? 'Please check your input and try again.';
      case ApiErrorCodes.serviceUnavailable:
        return 'Service is temporarily unavailable. Please try again later.';
      case ApiErrorCodes.suspiciousActivity:
        return 'Suspicious activity detected. Please contact support if this continues.';
      default:
        return message.isNotEmpty ? message : 'An unexpected error occurred.';
    }
  }

  /// Get appropriate icon for error type
  IconData get icon {
    switch (code) {
      case ApiErrorCodes.authTokenExpired:
      case ApiErrorCodes.authenticationFailed:
        return Icons.lock_outline;
      case ApiErrorCodes.rateLimitExceeded:
      case ApiErrorCodes.tooManyRequests:
        return Icons.timer_outlined;
      case ApiErrorCodes.fileTooLarge:
      case ApiErrorCodes.invalidFileType:
        return Icons.file_upload_outlined;
      case ApiErrorCodes.serviceUnavailable:
        return Icons.cloud_off_outlined;
      case ApiErrorCodes.suspiciousActivity:
        return Icons.security_outlined;
      default:
        return Icons.error_outline;
    }
  }

  /// Get appropriate color for error type
  Color get color {
    switch (code) {
      case ApiErrorCodes.authTokenExpired:
        return Colors.orange;
      case ApiErrorCodes.authTokenRevoked:
      case ApiErrorCodes.authenticationFailed:
        return Colors.red;
      case ApiErrorCodes.rateLimitExceeded:
      case ApiErrorCodes.tooManyRequests:
        return Colors.amber;
      case ApiErrorCodes.serviceUnavailable:
        return Colors.grey;
      case ApiErrorCodes.suspiciousActivity:
        return Colors.deepOrange;
      default:
        return Colors.red;
    }
  }

  @override
  String toString() {
    return 'ApiError(message: $message, code: $code, statusCode: $statusCode)';
  }
}

/// Enhanced Error Handler with automatic recovery
class ErrorHandler {
  static const int maxRetryAttempts = 3;
  static const Duration baseRetryDelay = Duration(seconds: 1);

  /// Handle API error with appropriate action
  static Future<ErrorAction> handleApiError(
    ApiError error, {
    VoidCallback? onTokenRefresh,
    VoidCallback? onReauthRequired,
    int currentRetryCount = 0,
  }) async {
    // Log error for debugging
    debugPrint('API Error: ${error.toString()}');

    // Handle token refresh
    if (error.requiresTokenRefresh && onTokenRefresh != null) {
      if (currentRetryCount < maxRetryAttempts) {
        onTokenRefresh();
        return ErrorAction.retryAfterTokenRefresh;
      } else {
        return ErrorAction.requiresReauth;
      }
    }

    // Handle re-authentication requirement
    if (error.requiresReauth && onReauthRequired != null) {
      onReauthRequired();
      return ErrorAction.requiresReauth;
    }

    // Handle retryable errors
    if (error.isRetryable && currentRetryCount < maxRetryAttempts) {
      final delay = _calculateRetryDelay(currentRetryCount, error);
      await Future.delayed(delay);
      return ErrorAction.retry;
    }

    // Show error to user
    return ErrorAction.showError;
  }

  /// Calculate retry delay with exponential backoff
  static Duration _calculateRetryDelay(int attempt, ApiError error) {
    // For rate limiting, use the server-provided retry-after if available
    if (error.code == ApiErrorCodes.rateLimitExceeded || 
        error.code == ApiErrorCodes.tooManyRequests) {
      final retryAfter = error.details?['retryAfter'] as int?;
      if (retryAfter != null) {
        return Duration(seconds: retryAfter);
      }
    }

    // Exponential backoff: 1s, 2s, 4s, 8s...
    final exponentialDelay = baseRetryDelay * (1 << attempt);
    
    // Add jitter to prevent thundering herd
    final jitter = Duration(milliseconds: (500 * (0.5 + (DateTime.now().millisecondsSinceEpoch % 1000) / 1000)).round());
    
    return exponentialDelay + jitter;
  }
}

/// Error Action enum
enum ErrorAction {
  retry,
  retryAfterTokenRefresh,
  requiresReauth,
  showError,
}

/// Error Display Widget
class ErrorDisplayWidget extends StatelessWidget {
  final ApiError error;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;
  final bool showDetails;

  const ErrorDisplayWidget({
    super.key,
    required this.error,
    this.onRetry,
    this.onDismiss,
    this.showDetails = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: error.color.withOpacity(0.1),
        border: Border.all(color: error.color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(error.icon, color: error.color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  error.userMessage,
                  style: TextStyle(
                    color: error.color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (onDismiss != null)
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onDismiss,
                  iconSize: 18,
                ),
            ],
          ),
          if (showDetails && error.details != null) ...[
            const SizedBox(height: 8),
            Text(
              'Details: ${error.details}',
              style: TextStyle(
                color: error.color.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
          if (onRetry != null && error.isRetryable) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: error.color,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }
}