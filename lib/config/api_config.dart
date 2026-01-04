class ApiConfig {
  static const String baseUrl = 'https://ary-lendly-production.up.railway.app';
  static const String apiVersion = 'v1';
  
  // Timeout configurations
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  
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
  static const int maxFileSize = 10 * 1024 * 1024; // 10MB
  static const List<String> allowedImageTypes = [
    'image/jpeg',
    'image/png', 
    'image/gif',
    'image/webp'
  ];
}