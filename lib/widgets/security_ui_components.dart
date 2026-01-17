/// Security-Aware UI Components for Enhanced User Experience
/// Provides smart error handling and security feedback to users
import 'package:flutter/material.dart';
import '../utils/enhanced_error_handling.dart';
import '../providers/enhanced_user_provider.dart';
import 'package:provider/provider.dart';
/// Smart Error Display Widget with Security Context
class SmartErrorDisplay extends StatelessWidget {
  final ApiError? error;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;
  final bool showDetails;
  final EdgeInsets? margin;
  const SmartErrorDisplay({
    super.key,
    this.error,
    this.onRetry,
    this.onDismiss,
    this.showDetails = false,
    this.margin,
  });
  @override
  Widget build(BuildContext context) {
    if (error == null) return const SizedBox.shrink();
    return Container(
      margin: margin ?? const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: error!.color.withOpacity(0.1),
        border: Border.all(color: error!.color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                error!.icon,
                color: error!.color,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getErrorTitle(),
                      style: TextStyle(
                        color: error!.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      error!.userMessage,
                      style: TextStyle(
                        color: error!.color.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (onDismiss != null)
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: error!.color,
                  ),
                  onPressed: onDismiss,
                  iconSize: 20,
                ),
            ],
          ),
          if (showDetails && error!.details != null) ..[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: error!.color.withOpacity(0.05),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Details: ${error!.details}',
                style: TextStyle(
                  color: error!.color.withOpacity(0.7),
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
          if (_shouldShowActionButtons()) ..[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (error!.requiresReauth) ..[
                  TextButton.icon(
                    onPressed: () => _handleReauth(context),
                    icon: const Icon(Icons.login),
                    label: const Text('Sign In Again'),
                    style: TextButton.styleFrom(
                      foregroundColor: error!.color,
                    ),
                  ),
                ] else if (error!.requiresTokenRefresh) ..[
                  TextButton.icon(
                    onPressed: () => _handleTokenRefresh(context),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh Session'),
                    style: TextButton.styleFrom(
                      foregroundColor: error!.color,
                    ),
                  ),
                ] else if (onRetry != null && error!.isRetryable) ..[
                  TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                    style: TextButton.styleFrom(
                      foregroundColor: error!.color,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
  String _getErrorTitle() {
    switch (error!.code) {
      case ApiErrorCodes.authTokenExpired:
        return 'Session Expired';
      case ApiErrorCodes.authTokenRevoked:
      case ApiErrorCodes.authenticationFailed:
        return 'Authentication Required';
      case ApiErrorCodes.rateLimitExceeded:
      case ApiErrorCodes.tooManyRequests:
        return 'Rate Limited';
      case ApiErrorCodes.fileTooLarge:
      case ApiErrorCodes.invalidFileType:
        return 'File Upload Error';
      case ApiErrorCodes.serviceUnavailable:
        return 'Service Unavailable';
      case ApiErrorCodes.suspiciousActivity:
        return 'Security Alert';
      default:
        return 'Error';
    }
  }
  bool _shouldShowActionButtons() {
    return error!.requiresReauth || 
           error!.requiresTokenRefresh || 
           (error!.isRetryable && onRetry != null);
  }
  void _handleReauth(BuildContext context) {
    final userProvider = Provider.of<EnhancedUserProvider>(context, listen: false);
    userProvider.signOut();
    // Navigation to login screen would be handled by the app
    Navigator.of(context).pushReplacementNamed('/login');
  }
  void _handleTokenRefresh(BuildContext context) {
    final userProvider = Provider.of<EnhancedUserProvider>(context, listen: false);
    userProvider.refreshUserData();
  }
}
/// Security Status Indicator Widget
class SecurityStatusIndicator extends StatelessWidget {
  final bool isTokenFresh;
  final bool hasRecentErrors;
  final VoidCallback? onTap;
  const SecurityStatusIndicator({
    super.key,
    required this.isTokenFresh,
    required this.hasRecentErrors,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor();
    final icon = _getStatusIcon();
    final tooltip = _getTooltip();
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            border: Border.all(color: color.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Text(
                _getStatusText(),
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Color _getStatusColor() {
    if (hasRecentErrors) return Colors.red;
    if (!isTokenFresh) return Colors.orange;
    return Colors.green;
  }
  IconData _getStatusIcon() {
    if (hasRecentErrors) return Icons.security;
    if (!isTokenFresh) return Icons.token;
    return Icons.verified;
  }
  String _getStatusText() {
    if (hasRecentErrors) return 'Issues';
    if (!isTokenFresh) return 'Refreshing';
    return 'Secure';
  }
  String _getTooltip() {
    if (hasRecentErrors) return 'Security issues detected. Tap for details.';
    if (!isTokenFresh) return 'Session is being refreshed for security.';
    return 'Your connection is secure.';
  }
}
/// Enhanced Loading State with Security Context
class SecurityAwareLoadingIndicator extends StatelessWidget {
  final String? message;
  final bool isTokenRefreshing;
  final double? progress;
  const SecurityAwareLoadingIndicator({
    super.key,
    this.message,
    this.isTokenRefreshing = false,
    this.progress,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (progress != null)
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.withOpacity(0.3),
              valueColor: AlwaysStoppedAnimation<Color>(
                isTokenRefreshing ? Colors.orange : Theme.of(context).primaryColor,
              ),
            )
          else
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                isTokenRefreshing ? Colors.orange : Theme.of(context).primaryColor,
              ),
            ),
          const SizedBox(height: 16),
          if (isTokenRefreshing) ..[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.security,
                  color: Colors.orange,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Refreshing security token...',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ] else if (message != null) ..[
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
/// Trust Score Display Widget
class TrustScoreWidget extends StatelessWidget {
  final double trustScore;
  final String tier;
  final bool showDetails;
  final VoidCallback? onTap;
  const TrustScoreWidget({
    super.key,
    required this.trustScore,
    required this.tier,
    this.showDetails = true,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final color = _getTierColor();
    final icon = _getTierIcon();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tier,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (showDetails)
                  Text(
                    '${trustScore.toInt()}/100',
                    style: TextStyle(
                      color: color.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  Color _getTierColor() {
    switch (tier.toLowerCase()) {
      case 'gold':
        return Colors.amber;
      case 'silver':
        return Colors.grey;
      default:
        return Colors.brown;
    }
  }
  IconData _getTierIcon() {
    switch (tier.toLowerCase()) {
      case 'gold':
        return Icons.military_tech;
      case 'silver':
        return Icons.star;
      default:
        return Icons.star_border;
    }
  }
}
/// Coins Balance Display Widget
class CoinsBalanceWidget extends StatelessWidget {
  final int balance;
  final VoidCallback? onTap;
  final bool showIcon;
  const CoinsBalanceWidget({
    super.key,
    required this.balance,
    this.onTap,
    this.showIcon = true,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.1),
          border: Border.all(color: Colors.amber.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showIcon) ..[
              const Icon(
                Icons.monetization_on,
                color: Colors.amber,
                size: 18,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              _formatBalance(),
              style: const TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
  String _formatBalance() {
    if (balance >= 1000000) {
      return '${(balance / 1000000).toStringAsFixed(1)}M';
    } else if (balance >= 1000) {
      return '${(balance / 1000).toStringAsFixed(1)}K';
    }
    return balance.toString();
  }
}
/// File Upload Security Indicator
class FileUploadSecurityIndicator extends StatelessWidget {
  final bool isSecure;
  final String? securityMessage;
  const FileUploadSecurityIndicator({
    super.key,
    required this.isSecure,
    this.securityMessage,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSecure ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSecure ? Icons.verified : Icons.warning,
            color: isSecure ? Colors.green : Colors.orange,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            securityMessage ?? (isSecure ? 'Secure Upload' : 'Upload Validation'),
            style: TextStyle(
              color: isSecure ? Colors.green : Colors.orange,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}