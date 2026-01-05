import 'env_config.dart';

class ApiConfig {
  /// Use environment-based URL
  static String get baseUrl => EnvConfig.apiBaseUrl;
  
  // For backwards compatibility - these now use EnvConfig
  static const String apiVersion = 'v1';
  
  // Timeout configurations - use EnvConfig values
  static Duration get connectTimeout => EnvConfig.connectionTimeoutDuration;
  static Duration get receiveTimeout => EnvConfig.receiveTimeoutDuration;
  
  // Endpoints
  static const String authEndpoint = '/auth';
  static const String userEndpoint = '/user';
  static const String itemsEndpoint = '/items';
  static const String transactionsEndpoint = '/transactions';
  static const String walletEndpoint = '/wallet';
  static const String adminEndpoint = '/admin';
  static const String chatEndpoint = '/chat';
  static const String groupsEndpoint = '/groups';
  static const String impactEndpoint = '/impact';
  static const String homeEndpoint = '/home';
  
  // File upload limits
  static int get maxFileSize => EnvConfig.maxImageSize * 1024; // Convert KB to bytes
  static const List<String> allowedImageTypes = [
    'image/jpeg',
    'image/png', 
    'image/gif',
    'image/webp'
  ];
  
  // Helper methods
  static String buildUrl(String endpoint) => '$baseUrl$endpoint';
  
  static Map<String, String> get defaultHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'X-App-Version': EnvConfig.appVersion,
  };
}