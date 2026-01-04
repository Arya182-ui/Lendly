import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Centralized API client with caching, retry logic, and error handling
class ApiClient {
  static const String baseUrl = 'https://ary-lendly-production.up.railway.app';
  
  // Simple in-memory cache with size limit
  static final Map<String, _CacheEntry> _cache = {};
  static const int _maxCacheSize = 100;
  static const Duration _defaultTimeout = Duration(seconds: 10);
  
  /// GET request with optional caching and retry logic
  static Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParams,
    Duration? cacheDuration,
    bool forceRefresh = false,
    int maxRetries = 3,
  }) async {
    assert(endpoint.isNotEmpty, 'Endpoint cannot be empty');
    
    final uri = Uri.parse('$baseUrl$endpoint').replace(queryParameters: queryParams);
    final cacheKey = uri.toString();
    
    // Check cache first (unless force refresh)
    if (!forceRefresh && cacheDuration != null) {
      final cached = _cache[cacheKey];
      if (cached != null && !cached.isExpired) {
        return cached.data;
      }
    }
    
    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        final response = await http.get(uri).timeout(_defaultTimeout);
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          
          // Store in cache if caching is enabled
          if (cacheDuration != null) {
            _cleanCacheIfNeeded();
            _cache[cacheKey] = _CacheEntry(data, cacheDuration);
          }
          
          return data;
        }
        
        // Don't retry for client errors (4xx)
        if (response.statusCode >= 400 && response.statusCode < 500) {
          throw ApiException(_parseError(response.body), response.statusCode, response.body);
        }
        
        throw ApiException('Request failed', response.statusCode, response.body);
      } on TimeoutException {
        attempts++;
        if (attempts >= maxRetries) {
          throw ApiException('Request timed out. Please check your connection.', 408, '');
        }
        await Future.delayed(Duration(milliseconds: 500 * attempts));
      } on SocketException {
        throw ApiException('No internet connection. Please check your network.', 0, '');
      } on FormatException {
        throw ApiException('Invalid response from server.', 0, '');
      }
    }
    throw ApiException('Request failed after $maxRetries attempts', 0, '');
  }
  
  /// POST request with error handling
  static Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    int maxRetries = 2,
  }) async {
    assert(endpoint.isNotEmpty, 'Endpoint cannot be empty');
    
    final uri = Uri.parse('$baseUrl$endpoint');
    
    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        final response = await http.post(
          uri,
          headers: {'Content-Type': 'application/json', ...?headers},
          body: body != null ? jsonEncode(body) : null,
        ).timeout(const Duration(seconds: 15));
        
        if (response.statusCode == 200 || response.statusCode == 201) {
          return jsonDecode(response.body);
        }
        
        // Don't retry for client errors (4xx)
        if (response.statusCode >= 400 && response.statusCode < 500) {
          throw ApiException(_parseError(response.body), response.statusCode, response.body);
        }
        
        throw ApiException(_parseError(response.body), response.statusCode, response.body);
      } on TimeoutException {
        attempts++;
        if (attempts >= maxRetries) {
          throw ApiException('Request timed out. Please try again.', 408, '');
        }
        await Future.delayed(Duration(milliseconds: 500 * attempts));
      } on SocketException {
        throw ApiException('No internet connection. Please check your network.', 0, '');
      } on FormatException {
        throw ApiException('Invalid response from server.', 0, '');
      }
    }
    throw ApiException('Request failed after $maxRetries attempts', 0, '');
  }
  
  /// PUT request with error handling
  static Future<dynamic> put(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    assert(endpoint.isNotEmpty, 'Endpoint cannot be empty');
    
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final response = await http.put(
        uri,
        headers: {'Content-Type': 'application/json', ...?headers},
        body: body != null ? jsonEncode(body) : null,
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      }
      
      throw ApiException(_parseError(response.body), response.statusCode, response.body);
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.', 408, '');
    } on SocketException {
      throw ApiException('No internet connection. Please check your network.', 0, '');
    }
  }
  
  /// DELETE request with error handling
  static Future<dynamic> delete(String endpoint) async {
    assert(endpoint.isNotEmpty, 'Endpoint cannot be empty');
    
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final response = await http.delete(uri).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200 || response.statusCode == 204) {
        if (response.body.isEmpty) return {'success': true};
        return jsonDecode(response.body);
      }
      
      throw ApiException(_parseError(response.body), response.statusCode, response.body);
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.', 408, '');
    } on SocketException {
      throw ApiException('No internet connection. Please check your network.', 0, '');
    }
  }
  
  /// Parse error message from response body
  static String _parseError(String body) {
    try {
      final json = jsonDecode(body);
      return json['error'] ?? json['message'] ?? 'An error occurred';
    } catch (_) {
      return 'An error occurred';
    }
  }
  
  /// Clean cache if it exceeds max size
  static void _cleanCacheIfNeeded() {
    if (_cache.length >= _maxCacheSize) {
      // Remove expired entries first
      _cache.removeWhere((_, entry) => entry.isExpired);
      
      // If still too large, remove oldest half
      if (_cache.length >= _maxCacheSize) {
        final keys = _cache.keys.take(_maxCacheSize ~/ 2).toList();
        for (final key in keys) {
          _cache.remove(key);
        }
      }
    }
  }
  
  /// Clear all cache
  static void clearCache() {
    _cache.clear();
  }
  
  /// Clear specific cache entry
  static void clearCacheEntry(String endpoint) {
    _cache.removeWhere((key, _) => key.contains(endpoint));
  }
  
  /// Invalidate user-related cache (useful after profile updates)
  static void invalidateUserCache(String uid) {
    _cache.removeWhere((key, _) => key.contains(uid));
  }
}

class _CacheEntry {
  final dynamic data;
  final DateTime expiresAt;
  
  _CacheEntry(this.data, Duration duration) 
      : expiresAt = DateTime.now().add(duration);
  
  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  final String body;
  
  ApiException(this.message, this.statusCode, this.body);
  
  @override
  String toString() => '$message (Status: $statusCode)';
}
