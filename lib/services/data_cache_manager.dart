import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized data cache manager for persistent offline caching
/// Reduces server requests significantly by caching data locally
class DataCacheManager {
  static const String _cachePrefix = 'cache_';
  static const String _timestampPrefix = 'timestamp_';
  
  // Cache durations for different data types (in minutes)
  static const Map<String, int> cacheDurations = {
    'user_summary': 5,       // User profile summary - 5 mins
    'new_arrivals': 3,       // New arrivals - 3 mins  
    'items_near_you': 2,     // Location based - 2 mins
    'groups': 5,             // Groups - 5 mins
    'impact_personal': 10,   // Impact data - 10 mins
    'impact_environmental': 10,
    'impact_community': 10,
    'impact_leaderboard': 10,
    'impact_badges': 15,     // Badges change less frequently
    'notifications': 1,      // Notifications - 1 min
    'wallet': 2,             // Wallet balance - 2 mins
    'friends': 5,            // Friends list - 5 mins
    'messages': 1,           // Messages - 1 min
  };
  
  static SharedPreferences? _prefs;
  
  /// Initialize the cache manager
  static Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }
  
  /// Get cached data if valid, otherwise return null
  static Future<T?> getCached<T>(String key) async {
    await initialize();
    
    final cacheKey = '$_cachePrefix$key';
    final timestampKey = '$_timestampPrefix$key';
    
    final cachedData = _prefs!.getString(cacheKey);
    final cachedTimestamp = _prefs!.getInt(timestampKey);
    
    if (cachedData == null || cachedTimestamp == null) {
      return null;
    }
    
    // Check if cache is still valid
    final duration = cacheDurations[key] ?? 5;
    final expiryTime = cachedTimestamp + (duration * 60 * 1000);
    
    if (DateTime.now().millisecondsSinceEpoch > expiryTime) {
      // Cache expired, remove it
      await _prefs!.remove(cacheKey);
      await _prefs!.remove(timestampKey);
      return null;
    }
    
    try {
      final decoded = jsonDecode(cachedData);
      return decoded as T;
    } catch (e) {
      return null;
    }
  }
  
  /// Store data in cache
  static Future<void> setCache(String key, dynamic data) async {
    await initialize();
    
    final cacheKey = '$_cachePrefix$key';
    final timestampKey = '$_timestampPrefix$key';
    
    try {
      await _prefs!.setString(cacheKey, jsonEncode(data));
      await _prefs!.setInt(timestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      // Silently fail - caching is optional
    }
  }
  
  /// Clear specific cache entry
  static Future<void> clearCache(String key) async {
    await initialize();
    
    final cacheKey = '$_cachePrefix$key';
    final timestampKey = '$_timestampPrefix$key';
    
    await _prefs!.remove(cacheKey);
    await _prefs!.remove(timestampKey);
  }
  
  /// Clear all cached data
  static Future<void> clearAllCache() async {
    await initialize();
    
    final keys = _prefs!.getKeys();
    for (final key in keys) {
      if (key.startsWith(_cachePrefix) || key.startsWith(_timestampPrefix)) {
        await _prefs!.remove(key);
      }
    }
  }
  
  /// Check if cache is valid for a key
  static Future<bool> isCacheValid(String key) async {
    await initialize();
    
    final timestampKey = '$_timestampPrefix$key';
    final cachedTimestamp = _prefs!.getInt(timestampKey);
    
    if (cachedTimestamp == null) return false;
    
    final duration = cacheDurations[key] ?? 5;
    final expiryTime = cachedTimestamp + (duration * 60 * 1000);
    
    return DateTime.now().millisecondsSinceEpoch <= expiryTime;
  }
  
  /// Get cache age in seconds
  static Future<int?> getCacheAge(String key) async {
    await initialize();
    
    final timestampKey = '$_timestampPrefix$key';
    final cachedTimestamp = _prefs!.getInt(timestampKey);
    
    if (cachedTimestamp == null) return null;
    
    return (DateTime.now().millisecondsSinceEpoch - cachedTimestamp) ~/ 1000;
  }
}
