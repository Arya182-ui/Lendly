/// Lendly Application Configuration
/// Centralized constants and configuration settings
class AppConfig {
  // App Information
  static const String appName = 'Lendly';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'Peer-to-peer lending for students';
  
  // UI Configuration
  static const double defaultBorderRadius = 12.0;
  static const double cardBorderRadius = 16.0;
  static const double buttonHeight = 48.0;
  
  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);
  
  // Network Configuration
  static const Duration networkTimeout = Duration(seconds: 30);
  static const int maxRetries = 3;
  
  // Cache Configuration  
  static const Duration shortCacheDuration = Duration(minutes: 2);
  static const Duration mediumCacheDuration = Duration(minutes: 5);
  static const Duration longCacheDuration = Duration(minutes: 15);
  
  // Business Rules
  static const int maxImageSizeMB = 5;
  static const int maxFileUploadMB = 10;
  static const int itemsPerPage = 20;
  static const int maxTrustScore = 100;
  
  // Feature Flags
  static const bool enableOfflineMode = true;
  static const bool enablePushNotifications = true;
  static const bool enableAnalytics = false; // Disabled for privacy
  
  // Validation Rules
  static const int minPasswordLength = 8;
  static const int maxItemNameLength = 100;
  static const int maxDescriptionLength = 500;
}
