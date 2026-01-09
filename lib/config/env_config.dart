/// Environment configuration for Lendly app
/// Supports multiple environments: development, staging, production
/// 
/// Usage:
/// - Loads from .env file using flutter_dotenv
/// - Fallback to String.fromEnvironment for CI/CD
/// - Or use flavor-specific builds
library;

import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  // Initialize dotenv
  static Future<void> load() async {
    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      print('Warning: Could not load .env file: $e');
    }
  }

  // Environment determination  
  static String get environment => 
    dotenv.env['ENVIRONMENT'] ?? 
    const String.fromEnvironment('ENVIRONMENT', defaultValue: 'production');
  
  // API Configuration
  static String get apiBaseUrl => 
    dotenv.env['API_BASE_URL'] ?? 
    const String.fromEnvironment('API_BASE_URL', defaultValue: 'https://ary-lendly-production.up.railway.app');
  
  // Socket.IO Configuration  
  static String get socketUrl => 
    dotenv.env['SOCKET_URL'] ?? 
    const String.fromEnvironment('SOCKET_URL', defaultValue: 'https://ary-lendly-production.up.railway.app');
  
  // Feature Flags
  static bool get enableAnalytics => 
    (dotenv.env['ENABLE_ANALYTICS']?.toLowerCase() == 'true') ||
    const bool.fromEnvironment('ENABLE_ANALYTICS', defaultValue: true);
  
  static bool get enableCrashReporting => 
    (dotenv.env['ENABLE_CRASH_REPORTING']?.toLowerCase() == 'true') ||
    const bool.fromEnvironment('ENABLE_CRASH_REPORTING', defaultValue: true);
  
  static bool get enableDebugMode => 
    (dotenv.env['DEBUG_MODE']?.toLowerCase() == 'true') ||
    const bool.fromEnvironment('DEBUG_MODE', defaultValue: false);
  
  static bool get enableOfflineMode => 
    (dotenv.env['ENABLE_OFFLINE_MODE']?.toLowerCase() == 'true') ||
    const bool.fromEnvironment('ENABLE_OFFLINE_MODE', defaultValue: true);
  
  static bool get enableImageCompression => 
    (dotenv.env['ENABLE_IMAGE_COMPRESSION']?.toLowerCase() == 'true') ||
    const bool.fromEnvironment('ENABLE_IMAGE_COMPRESSION', defaultValue: true);
  
  // Cache Configuration
  static int get cacheMaxAge => 
    int.tryParse(dotenv.env['CACHE_MAX_AGE_MINUTES'] ?? '') ??
    const int.fromEnvironment('CACHE_MAX_AGE_MINUTES', defaultValue: 30);
  
  static int get cacheMaxSize => 
    int.tryParse(dotenv.env['CACHE_MAX_SIZE_MB'] ?? '') ??
    const int.fromEnvironment('CACHE_MAX_SIZE_MB', defaultValue: 50);
  
  // Network Configuration
  static const int connectionTimeout = int.fromEnvironment(
    'CONNECTION_TIMEOUT_SECONDS',
    defaultValue: 30,
  );
  
  static const int receiveTimeout = int.fromEnvironment(
    'RECEIVE_TIMEOUT_SECONDS',
    defaultValue: 30,
  );
  
  static const int maxRetries = int.fromEnvironment(
    'MAX_RETRIES',
    defaultValue: 3,
  );
  
  // App Configuration
  static const String appName = String.fromEnvironment(
    'APP_NAME',
    defaultValue: 'Lendly',
  );
  
  static const String appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0',
  );
  
  // Image Configuration
  static const int maxImageSize = int.fromEnvironment(
    'MAX_IMAGE_SIZE_KB',
    defaultValue: 1024, // 1MB
  );
  
  static const int imageQuality = int.fromEnvironment(
    'IMAGE_QUALITY',
    defaultValue: 85,
  );
  
  // Pagination
  static const int defaultPageSize = int.fromEnvironment(
    'DEFAULT_PAGE_SIZE',
    defaultValue: 20,
  );
  
  // Environment helpers
  static bool get isDevelopment => environment == 'development';
  static bool get isStaging => environment == 'staging';
  static bool get isProduction => environment == 'production';
  
  // Computed configurations
  static Duration get connectionTimeoutDuration => 
      Duration(seconds: connectionTimeout);
  
  static Duration get receiveTimeoutDuration => 
      Duration(seconds: receiveTimeout);
  
  static Duration get cacheMaxAgeDuration => 
      Duration(minutes: cacheMaxAge);
  
  // Debug logging
  static void printConfig() {
    if (enableDebugMode) {
    }
  }
}

/// Environment-specific API endpoints
class ApiEndpoints {
  static String get auth => '${EnvConfig.apiBaseUrl}/auth';
  static String get user => '${EnvConfig.apiBaseUrl}/user';
  static String get items => '${EnvConfig.apiBaseUrl}/items';
  static String get transactions => '${EnvConfig.apiBaseUrl}/transactions';
  static String get wallet => '${EnvConfig.apiBaseUrl}/wallet';
  static String get admin => '${EnvConfig.apiBaseUrl}/admin';
  static String get chat => '${EnvConfig.apiBaseUrl}/chat';
  static String get groups => '${EnvConfig.apiBaseUrl}/groups';
  static String get impact => '${EnvConfig.apiBaseUrl}/impact';
  static String get home => '${EnvConfig.apiBaseUrl}/home';
  static String get friends => '${EnvConfig.apiBaseUrl}/user';
  
  // Specific endpoints
  static String login() => '$auth/login';
  static String signup() => '$auth/signup';
  static String profile(String uid) => '$user/profile?uid=$uid';
  static String publicProfile(String uid) => '$user/public-profile?uid=$uid';
  static String userItems(String uid, {int limit = 10}) => '$user/items?uid=$uid&limit=$limit';
  static String userStats(String uid) => '$user/stats?uid=$uid';
  static String notifications(String uid) => '$user/notifications?uid=$uid';
  static String summary(String uid) => '$home/summary?uid=$uid';
  static String newArrivals() => '$home/new-arrivals';
  static String itemsNearYou(String uid, double lat, double lng) => 
      '$home/items-near-you?uid=$uid&latitude=$lat&longitude=$lng';
  static String groupsList() => '$home/groups';
  static String chatMessages(String chatId) => '$chat/messages/$chatId';
  static String sendMessage() => '$chat/send';
  static String walletBalance(String uid) => '$wallet/$uid';
  static String walletTransactions(String uid) => '$wallet/$uid/transactions';
}
