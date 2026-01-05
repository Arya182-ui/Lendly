import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/env_config.dart';
import 'firebase_auth_service.dart';
import 'app_logger.dart';

/// Enhanced API client with Firebase authentication, caching, retry logic, offline support, and error handling
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  final FirebaseAuthService _authService = FirebaseAuthService();
  
  // In-memory cache for fast access
  final Map<String, _CacheEntry> _memoryCache = {};
  static const int _maxMemoryCacheSize = 100;
  
  // Request queue for offline mode
  final List<_QueuedRequest> _requestQueue = [];
  bool _isOnline = true;
  
  // HTTP client with connection pooling
  final http.Client _client = http.Client();
  
  /// Initialize the API client
  Future<void> initialize() async {
    await _loadOfflineQueue();
    _startConnectivityMonitor();
  }

  /// GET request with caching and retry logic
  Future<ApiResponse<T>> get<T>(
    String endpoint, {
    Map<String, String>? queryParams,
    Duration? cacheDuration,
    bool forceRefresh = false,
    int maxRetries = EnvConfig.maxRetries,
    T Function(dynamic)? parser,
    bool requiresAuth = true,
  }) async {
    final uri = Uri.parse('${EnvConfig.apiBaseUrl}$endpoint')
        .replace(queryParameters: queryParams);
    final cacheKey = uri.toString();

    // Check memory cache first (unless force refresh)
    if (!forceRefresh && cacheDuration != null) {
      final cached = _memoryCache[cacheKey];
      if (cached != null && !cached.isExpired) {
        return ApiResponse.success(
          parser != null ? parser(cached.data) : cached.data as T,
          fromCache: true,
        );
      }
    }

    // Check persistent cache
    if (!forceRefresh && cacheDuration != null) {
      final persistentCache = await _getPersistentCache(cacheKey);
      if (persistentCache != null) {
        final data = parser != null ? parser(persistentCache) : persistentCache as T;
        // Refresh memory cache
        _memoryCache[cacheKey] = _CacheEntry(persistentCache, cacheDuration);
        return ApiResponse.success(data, fromCache: true);
      }
    }

    // If offline, return cached data or error
    if (!_isOnline) {
      final offlineData = await _getOfflineData(cacheKey);
      if (offlineData != null) {
        return ApiResponse.success(
          parser != null ? parser(offlineData) : offlineData as T,
          fromCache: true,
          isOffline: true,
        );
      }
      return ApiResponse.error('No internet connection', statusCode: 0, isOffline: true);
    }

    // Get headers with authentication if required
    final headers = await _getHeaders(requiresAuth: requiresAuth);
    if (requiresAuth && headers == null) {
      return ApiResponse.error('Authentication required', statusCode: 401);
    }

    // Make the request with retry logic
    int attempts = 0;
    Exception? lastError;

    while (attempts < maxRetries) {
      try {
        final response = await _client
            .get(uri, headers: headers ?? _defaultHeaders)
            .timeout(EnvConfig.connectionTimeoutDuration);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          
          // Store in caches
          if (cacheDuration != null) {
            _cleanMemoryCacheIfNeeded();
            _memoryCache[cacheKey] = _CacheEntry(data, cacheDuration);
            await _setPersistentCache(cacheKey, data, cacheDuration);
          }

          return ApiResponse.success(
            parser != null ? parser(data) : data as T,
          );
        }

        // Handle authentication errors by refreshing token
        if (response.statusCode == 401 && requiresAuth) {
          logger.warning('Auth token expired, refreshing...', tag: 'ApiClient');
          final refreshedHeaders = await _getHeaders(requiresAuth: true, forceRefresh: true);
          if (refreshedHeaders != null) {
            // Retry with refreshed token
            final retryResponse = await _client
                .get(uri, headers: refreshedHeaders)
                .timeout(EnvConfig.connectionTimeoutDuration);
            
            if (retryResponse.statusCode == 200) {
              final data = jsonDecode(retryResponse.body);
              return ApiResponse.success(parser != null ? parser(data) : data as T);
            }
          }
        }

        // Don't retry for client errors (4xx)
        if (response.statusCode >= 400 && response.statusCode < 500) {
          return ApiResponse.error(
            _parseError(response.body),
            statusCode: response.statusCode,
            rawResponse: response.body,
          );
        }

        lastError = ApiException(
          'Request failed',
          response.statusCode,
          response.body,
        );
      } on TimeoutException {
        lastError = ApiException('Request timed out', 408, '');
      } on SocketException {
        _isOnline = false;
        // Return cached data if available
        final offlineData = await _getOfflineData(cacheKey);
        if (offlineData != null) {
          return ApiResponse.success(
            parser != null ? parser(offlineData) : offlineData as T,
            fromCache: true,
            isOffline: true,
          );
        }
        return ApiResponse.error('No internet connection', statusCode: 0, isOffline: true);
      } on FormatException {
        lastError = ApiException('Invalid response format', 0, '');
      }

      attempts++;
      if (attempts < maxRetries) {
        await Future.delayed(Duration(milliseconds: 500 * attempts));
      }
    }

    return ApiResponse.error(
      lastError?.toString() ?? 'Request failed after $maxRetries attempts',
      statusCode: 0,
    );
  }

  /// POST request with offline queue support
  Future<ApiResponse<T>> post<T>(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    int maxRetries = 2,
    bool queueIfOffline = true,
    T Function(dynamic)? parser,
    bool requiresAuth = true,
  }) async {
    final uri = Uri.parse('${EnvConfig.apiBaseUrl}$endpoint');

    // If offline and queueable, add to queue
    if (!_isOnline && queueIfOffline) {
      await _addToQueue(_QueuedRequest(
        method: 'POST',
        endpoint: endpoint,
        body: body,
        headers: headers,
      ));
      return ApiResponse.queued('Request queued for later');
    }

    // Get headers with authentication if required
    final authHeaders = await _getHeaders(requiresAuth: requiresAuth);
    if (requiresAuth && authHeaders == null) {
      return ApiResponse.error('Authentication required', statusCode: 401);
    }

    final requestHeaders = {...(authHeaders ?? _defaultHeaders), ...?headers};

    int attempts = 0;
    Exception? lastError;

    while (attempts < maxRetries) {
      try {
        final response = await _client.post(
          uri,
          headers: requestHeaders,
          body: body != null ? jsonEncode(body) : null,
        ).timeout(EnvConfig.connectionTimeoutDuration);

        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = jsonDecode(response.body);
          return ApiResponse.success(
            parser != null ? parser(data) : data as T,
          );
        }

        // Handle authentication errors by refreshing token
        if (response.statusCode == 401 && requiresAuth) {
          logger.warning('Auth token expired, refreshing...', tag: 'ApiClient');
          final refreshedHeaders = await _getHeaders(requiresAuth: true, forceRefresh: true);
          if (refreshedHeaders != null) {
            final retryHeaders = {...refreshedHeaders, ...?headers};
            final retryResponse = await _client.post(
              uri,
              headers: retryHeaders,
              body: body != null ? jsonEncode(body) : null,
            ).timeout(EnvConfig.connectionTimeoutDuration);
            
            if (retryResponse.statusCode == 200 || retryResponse.statusCode == 201) {
              final data = jsonDecode(retryResponse.body);
              return ApiResponse.success(parser != null ? parser(data) : data as T);
            }
          }
        }

        if (response.statusCode >= 400 && response.statusCode < 500) {
          return ApiResponse.error(
            _parseError(response.body),
            statusCode: response.statusCode,
            rawResponse: response.body,
          );
        }

        lastError = ApiException('Request failed', response.statusCode, response.body);
      } on TimeoutException {
        lastError = ApiException('Request timed out', 408, '');
      } on SocketException {
        _isOnline = false;
        if (queueIfOffline) {
          await _addToQueue(_QueuedRequest(
            method: 'POST',
            endpoint: endpoint,
            body: body,
            headers: headers,
          ));
          return ApiResponse.queued('Request queued for later');
        }
        return ApiResponse.error('No internet connection', statusCode: 0, isOffline: true);
      }

      attempts++;
      if (attempts < maxRetries) {
        await Future.delayed(Duration(milliseconds: 500 * attempts));
      }
    }

    return ApiResponse.error(
      lastError?.toString() ?? 'Request failed',
      statusCode: 0,
    );
  }

  /// PUT request
  Future<ApiResponse<T>> put<T>(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    int maxRetries = 2,
    T Function(dynamic)? parser,
    bool requiresAuth = true,
  }) async {
    final uri = Uri.parse('${EnvConfig.apiBaseUrl}$endpoint');

    // Get headers with authentication if required
    final authHeaders = await _getHeaders(requiresAuth: requiresAuth);
    if (requiresAuth && authHeaders == null) {
      return ApiResponse.error('Authentication required', statusCode: 401);
    }

    final requestHeaders = {...(authHeaders ?? _defaultHeaders), ...?headers};

    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        final response = await _client.put(
          uri,
          headers: requestHeaders,
          body: body != null ? jsonEncode(body) : null,
        ).timeout(EnvConfig.connectionTimeoutDuration);

        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = jsonDecode(response.body);
          return ApiResponse.success(
            parser != null ? parser(data) : data as T,
          );
        }

        // Handle authentication errors
        if (response.statusCode == 401 && requiresAuth) {
          logger.warning('Auth token expired, refreshing...', tag: 'ApiClient');
          final refreshedHeaders = await _getHeaders(requiresAuth: true, forceRefresh: true);
          if (refreshedHeaders != null) {
            final retryHeaders = {...refreshedHeaders, ...?headers};
            final retryResponse = await _client.put(
              uri,
              headers: retryHeaders,
              body: body != null ? jsonEncode(body) : null,
            ).timeout(EnvConfig.connectionTimeoutDuration);
            
            if (retryResponse.statusCode == 200 || retryResponse.statusCode == 201) {
              final data = jsonDecode(retryResponse.body);
              return ApiResponse.success(parser != null ? parser(data) : data as T);
            }
          }
        }

        if (response.statusCode >= 400 && response.statusCode < 500) {
          return ApiResponse.error(
            _parseError(response.body),
            statusCode: response.statusCode,
          );
        }
      } on TimeoutException {
        // Continue to retry
      } on SocketException {
        return ApiResponse.error('No internet connection', statusCode: 0, isOffline: true);
      }

      attempts++;
      if (attempts < maxRetries) {
        await Future.delayed(Duration(milliseconds: 500 * attempts));
      }
    }

    return ApiResponse.error('Request failed', statusCode: 0);
  }

  /// DELETE request
  Future<ApiResponse<T>> delete<T>(
    String endpoint, {
    Map<String, String>? headers,
    T Function(dynamic)? parser,
    bool requiresAuth = true,
  }) async {
    final uri = Uri.parse('${EnvConfig.apiBaseUrl}$endpoint');

    // Get headers with authentication if required
    final authHeaders = await _getHeaders(requiresAuth: requiresAuth);
    if (requiresAuth && authHeaders == null) {
      return ApiResponse.error('Authentication required', statusCode: 401);
    }

    final requestHeaders = {...(authHeaders ?? _defaultHeaders), ...?headers};

    try {
      final response = await _client.delete(
        uri,
        headers: requestHeaders,
      ).timeout(EnvConfig.connectionTimeoutDuration);

      if (response.statusCode == 200 || response.statusCode == 204) {
        if (response.body.isEmpty) {
          return ApiResponse.success(null as T);
        }
        final data = jsonDecode(response.body);
        return ApiResponse.success(
          parser != null ? parser(data) : data as T,
        );
      }

      // Handle authentication errors
      if (response.statusCode == 401 && requiresAuth) {
        logger.warning('Auth token expired, refreshing...', tag: 'ApiClient');
        final refreshedHeaders = await _getHeaders(requiresAuth: true, forceRefresh: true);
        if (refreshedHeaders != null) {
          final retryHeaders = {...refreshedHeaders, ...?headers};
          final retryResponse = await _client.delete(
            uri,
            headers: retryHeaders,
          ).timeout(EnvConfig.connectionTimeoutDuration);
          
          if (retryResponse.statusCode == 200 || retryResponse.statusCode == 204) {
            if (retryResponse.body.isEmpty) {
              return ApiResponse.success(null as T);
            }
            final data = jsonDecode(retryResponse.body);
            return ApiResponse.success(parser != null ? parser(data) : data as T);
          }
        }
      }

      return ApiResponse.error(
        _parseError(response.body),
        statusCode: response.statusCode,
      );
    } on TimeoutException {
      return ApiResponse.error('Request timed out', statusCode: 408);
    } on SocketException {
      return ApiResponse.error('No internet connection', statusCode: 0, isOffline: true);
    }
  }

  /// Get headers with Firebase authentication
  Future<Map<String, String>?> _getHeaders({
    bool requiresAuth = true, 
    bool forceRefresh = false
  }) async {
    final baseHeaders = Map<String, String>.from(_defaultHeaders);
    
    if (!requiresAuth) {
      return baseHeaders;
    }

    try {
      // Get Firebase ID token
      String? token;
      if (forceRefresh) {
        token = await _authService.getIdToken(forceRefresh: true);
        logger.info('Force refreshed token', tag: 'ApiClient', data: {'hasToken': token != null});
      } else {
        // First try stored token, then get fresh one
        token = await _authService.getStoredIdToken();
        if (token == null) {
          token = await _authService.getIdToken();
          logger.info('Got fresh token (stored was null)', tag: 'ApiClient', data: {'hasToken': token != null});
        }
      }

      if (token == null) {
        logger.warning('No authentication token available - user may not be logged in', tag: 'ApiClient');
        return null;
      }

      baseHeaders['Authorization'] = 'Bearer $token';
      logger.info('Auth header set', tag: 'ApiClient', data: {'tokenLength': token.length});
      return baseHeaders;
    } catch (e) {
      logger.error('Failed to get authentication headers', tag: 'ApiClient', data: {'error': e.toString()});
      return null;
    }
  }

  /// Clear all caches
  Future<void> clearCache() async {
    _memoryCache.clear();
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('api_cache_'));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  /// Clear cache for specific endpoint
  void clearCacheEntry(String endpoint) {
    final keysToRemove = _memoryCache.keys
        .where((k) => k.contains(endpoint))
        .toList();
    for (final key in keysToRemove) {
      _memoryCache.remove(key);
    }
  }

  /// Process queued requests when back online
  Future<void> processQueue() async {
    if (_requestQueue.isEmpty || !_isOnline) return;

    final queue = List<_QueuedRequest>.from(_requestQueue);
    _requestQueue.clear();

    for (final request in queue) {
      if (request.method == 'POST') {
        await post(
          request.endpoint,
          body: request.body,
          headers: request.headers,
          queueIfOffline: false,
        );
      }
    }

    await _saveOfflineQueue();
  }

  /// Check connectivity status
  bool get isOnline => _isOnline;

  /// Set online status
  set isOnline(bool value) {
    final wasOffline = !_isOnline;
    _isOnline = value;
    if (wasOffline && _isOnline) {
      processQueue();
    }
  }

  // Private helpers
  Map<String, String> get _defaultHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'X-App-Version': EnvConfig.appVersion,
    'X-Platform': Platform.operatingSystem,
  };

  String _parseError(String body) {
    try {
      final data = jsonDecode(body);
      return data['error'] ?? data['message'] ?? 'Unknown error';
    } catch (_) {
      return 'Request failed';
    }
  }

  void _cleanMemoryCacheIfNeeded() {
    if (_memoryCache.length >= _maxMemoryCacheSize) {
      final entries = _memoryCache.entries.toList()
        ..sort((a, b) => a.value.createdAt.compareTo(b.value.createdAt));
      
      final toRemove = entries.take(_maxMemoryCacheSize ~/ 4).map((e) => e.key);
      for (final key in toRemove) {
        _memoryCache.remove(key);
      }
    }
  }

  Future<dynamic> _getPersistentCache(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'api_cache_$key';
    final expiryKey = 'api_cache_expiry_$key';
    
    final cached = prefs.getString(cacheKey);
    final expiry = prefs.getInt(expiryKey);
    
    if (cached == null || expiry == null) return null;
    if (DateTime.now().millisecondsSinceEpoch > expiry) {
      await prefs.remove(cacheKey);
      await prefs.remove(expiryKey);
      return null;
    }
    
    return jsonDecode(cached);
  }

  Future<void> _setPersistentCache(String key, dynamic data, Duration duration) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'api_cache_$key';
    final expiryKey = 'api_cache_expiry_$key';
    
    await prefs.setString(cacheKey, jsonEncode(data));
    await prefs.setInt(expiryKey, DateTime.now().add(duration).millisecondsSinceEpoch);
  }

  Future<dynamic> _getOfflineData(String key) async {
    // Try memory cache first (even if expired for offline mode)
    final memCached = _memoryCache[key];
    if (memCached != null) return memCached.data;
    
    // Try persistent cache
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('api_cache_$key');
    if (cached != null) return jsonDecode(cached);
    
    return null;
  }

  Future<void> _addToQueue(_QueuedRequest request) async {
    _requestQueue.add(request);
    await _saveOfflineQueue();
  }

  Future<void> _saveOfflineQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final queueData = _requestQueue.map((r) => r.toJson()).toList();
    await prefs.setString('offline_queue', jsonEncode(queueData));
  }

  Future<void> _loadOfflineQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final queueData = prefs.getString('offline_queue');
    if (queueData != null) {
      final list = jsonDecode(queueData) as List;
      _requestQueue.addAll(list.map((e) => _QueuedRequest.fromJson(e)));
    }
  }

  void _startConnectivityMonitor() {
    // Periodically check connectivity
    Timer.periodic(const Duration(seconds: 30), (_) async {
      try {
        final result = await InternetAddress.lookup('google.com')
            .timeout(const Duration(seconds: 5));
        isOnline = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      } catch (_) {
        isOnline = false;
      }
    });
  }

  /// Dispose resources
  void dispose() {
    _client.close();
  }
}

/// API Response wrapper
class ApiResponse<T> {
  final T? data;
  final String? error;
  final int? statusCode;
  final bool isSuccess;
  final bool fromCache;
  final bool isOffline;
  final bool isQueued;
  final String? rawResponse;

  ApiResponse._({
    this.data,
    this.error,
    this.statusCode,
    required this.isSuccess,
    this.fromCache = false,
    this.isOffline = false,
    this.isQueued = false,
    this.rawResponse,
  });

  factory ApiResponse.success(T data, {bool fromCache = false, bool isOffline = false}) {
    return ApiResponse._(
      data: data,
      isSuccess: true,
      fromCache: fromCache,
      isOffline: isOffline,
    );
  }

  factory ApiResponse.error(String error, {int? statusCode, String? rawResponse, bool isOffline = false}) {
    return ApiResponse._(
      error: error,
      statusCode: statusCode,
      isSuccess: false,
      isOffline: isOffline,
      rawResponse: rawResponse,
    );
  }

  factory ApiResponse.queued(String message) {
    return ApiResponse._(
      error: message,
      isSuccess: false,
      isQueued: true,
    );
  }

  /// Map success data to a new type
  ApiResponse<R> map<R>(R Function(T data) mapper) {
    if (isSuccess && data != null) {
      return ApiResponse.success(mapper(data!), fromCache: fromCache, isOffline: isOffline);
    }
    return ApiResponse.error(error ?? 'Unknown error', statusCode: statusCode);
  }
}

/// Cache entry with expiration
class _CacheEntry {
  final dynamic data;
  final DateTime createdAt;
  final DateTime expiresAt;

  _CacheEntry(this.data, Duration duration)
      : createdAt = DateTime.now(),
        expiresAt = DateTime.now().add(duration);

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Queued request for offline mode
class _QueuedRequest {
  final String method;
  final String endpoint;
  final Map<String, dynamic>? body;
  final Map<String, String>? headers;
  final DateTime createdAt;

  _QueuedRequest({
    required this.method,
    required this.endpoint,
    this.body,
    this.headers,
  }) : createdAt = DateTime.now();

  factory _QueuedRequest.fromJson(Map<String, dynamic> json) {
    return _QueuedRequest(
      method: json['method'],
      endpoint: json['endpoint'],
      body: json['body'],
      headers: json['headers']?.cast<String, String>(),
    );
  }

  Map<String, dynamic> toJson() => {
    'method': method,
    'endpoint': endpoint,
    'body': body,
    'headers': headers,
  };
}

/// API Exception
class ApiException implements Exception {
  final String message;
  final int statusCode;
  final String rawResponse;

  ApiException(this.message, this.statusCode, this.rawResponse);

  @override
  String toString() => message;
}

/// Simple API client wrapper for backward compatibility
class SimpleApiClient {
  static final _apiClient = ApiClient();

  static Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParams,
    Duration? cacheDuration,
    bool requiresAuth = true,
  }) async {
    final response = await _apiClient.get<dynamic>(
      endpoint,
      queryParams: queryParams,
      cacheDuration: cacheDuration,
      requiresAuth: requiresAuth,
    );
    
    if (response.isSuccess) {
      return response.data;
    } else {
      throw ApiException(response.error ?? 'Unknown error', response.statusCode ?? 0, '');
    }
  }

  static Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      endpoint,
      body: body,
      requiresAuth: requiresAuth,
    );
    
    if (response.isSuccess) {
      return response.data!;
    } else {
      throw ApiException(response.error ?? 'Unknown error', response.statusCode ?? 0, '');
    }
  }

  static Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    final response = await _apiClient.put<Map<String, dynamic>>(
      endpoint,
      body: body,
      requiresAuth: requiresAuth,
    );
    
    if (response.isSuccess) {
      return response.data!;
    } else {
      throw ApiException(response.error ?? 'Unknown error', response.statusCode ?? 0, '');
    }
  }

  static Future<Map<String, dynamic>> delete(
    String endpoint, {
    bool requiresAuth = true,
  }) async {
    final response = await _apiClient.delete<Map<String, dynamic>>(
      endpoint,
      requiresAuth: requiresAuth,
    );
    
    if (response.isSuccess) {
      return response.data ?? {};
    } else {
      throw ApiException(response.error ?? 'Unknown error', response.statusCode ?? 0, '');
    }
  }

  /// Clear cache entry - backward compatibility method
  static void clearCacheEntry(String endpoint) {
    _apiClient.clearCacheEntry(endpoint);
  }

  /// Invalidate user cache - backward compatibility method
  static void invalidateUserCache() {
    _apiClient.clearCacheEntry('/user');
  }
}