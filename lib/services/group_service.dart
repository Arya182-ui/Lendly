import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import '../config/api_config.dart';
import 'app_logger.dart';
import 'firebase_auth_service.dart';

class GroupService extends ChangeNotifier {
  // Use ApiConfig instead of hardcoded URL
  static String get baseUrl => ApiConfig.baseUrl;
  static const Duration _timeout = Duration(seconds: 30);
  
  final FirebaseAuthService _authService = FirebaseAuthService();
  
  // Validation constants
  static const int MAX_NAME_LENGTH = 50;
  static const int MAX_DESCRIPTION_LENGTH = 500;
  static const int MAX_MEMBERS = 100;
  static const List<String> ALLOWED_GROUP_TYPES = ['study', 'social', 'project', 'sports', 'other'];
  
  // Cache for groups
  final Map<String, dynamic> _groupsCache = {};
  final Map<String, Timer> _cacheTimers = {};
  static const Duration cacheTimeout = Duration(minutes: 5);

  /// Get auth headers with Firebase token
  Future<Map<String, String>> _getAuthHeaders() async {
    final Map<String, String> headers = {'Content-Type': 'application/json'};
    try {
      final token = await _authService.getIdToken();
      if (token != null && token.isNotEmpty) {
        logger.debug('Auth token obtained for groups');
        headers['Authorization'] = 'Bearer $token';
      } else {
        logger.debug('Warning: No auth token available for groups');
      }
    } catch (e) {
      logger.debug('Failed to get auth token: $e');
    }
    return headers;
  }

  /// Fetch all groups for a user
  Future<List<Map<String, dynamic>>> fetchGroups(String uid) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/groups/my?uid=$uid'),
        headers: await _getAuthHeaders(),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Backend returns array directly
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data['groups'] != null) {
          return List<Map<String, dynamic>>.from(data['groups']);
        }
        return [];
      } else {
        throw Exception('Failed to fetch groups: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Request timeout - please check your internet connection');
    } on SocketException {
      throw Exception('No internet connection available');
    } catch (e) {
      throw Exception('Failed to fetch groups: $e');
    }
  }

  /// Join a group
  Future<Map<String, dynamic>> joinGroup(String groupId, String uid) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/groups/$groupId/join'),
        headers: await _getAuthHeaders(),
        body: json.encode({'uid': uid}),
      ).timeout(_timeout);

      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['error'] ?? 'Failed to join group');
      }
    } on TimeoutException {
      throw Exception('Request timeout - please check your internet connection');
    } on SocketException {
      throw Exception('No internet connection available');
    } catch (e) {
      throw Exception('Failed to join group: $e');
    }
  }

  /// Leave a group
  Future<Map<String, dynamic>> leaveGroup(String groupId, String uid) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/groups/$groupId/leave'),
        headers: await _getAuthHeaders(),
        body: json.encode({'uid': uid}),
      ).timeout(_timeout);

      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['error'] ?? 'Failed to leave group');
      }
    } on TimeoutException {
      throw Exception('Request timeout - please check your internet connection');
    } on SocketException {
      throw Exception('No internet connection available');
    } catch (e) {
      throw Exception('Failed to leave group: $e');
    }
  }

  /// Fetch groups for discovery
  Future<List<Map<String, dynamic>>> fetchDiscoverGroups({
    required String uid,
    int limit = 20,
    String? query,
    String? type,
  }) async {
    try {
      final queryParams = <String, String>{
        'uid': uid,
        'limit': limit.toString(),
      };
      
      if (query != null && query.isNotEmpty) {
        queryParams['query'] = query;
      }
      
      if (type != null && type.isNotEmpty) {
        queryParams['type'] = type;
      }

      final uri = Uri.parse('$baseUrl/groups/discover').replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: await _getAuthHeaders(),
      ).timeout(_timeout);

      logger.debug('✅ Discover groups status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        logger.debug('📦 Response data type: ${data.runtimeType}');
        
        // Backend returns array directly, not wrapped in 'groups' key
        if (data is List) {
          logger.debug('✅ Got ${data.length} groups as List');
          return List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data['groups'] != null) {
          logger.debug('✅ Got groups from Map wrapper');
          return List<Map<String, dynamic>>.from(data['groups']);
        } else {
          logger.debug('⚠️ Unexpected format, returning empty list');
          return [];
        }
      } else {
        final data = json.decode(response.body);
        logger.debug('❌ Error response: $data');
        throw Exception(data['error'] ?? 'Failed to fetch discover groups');
      }
    } on TimeoutException {
      throw Exception('Request timeout - please check your internet connection');
    } on SocketException {
      throw Exception('No internet connection available');
    } catch (e) {
      throw Exception('Failed to fetch discover groups: $e');
    }
  }

  /// Get trending groups
  Future<List<Map<String, dynamic>>> getTrendingGroups() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/groups/trending'),
        headers: await _getAuthHeaders(),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['groups'] ?? []);
      } else {
        throw Exception('Failed to fetch trending groups');
      }
    } on TimeoutException {
      throw Exception('Request timeout - please check your internet connection');
    } on SocketException {
      throw Exception('No internet connection available');
    } catch (e) {
      throw Exception('Failed to fetch trending groups: $e');
    }
  }

  /// Get group suggestions
  Future<List<Map<String, dynamic>>> getGroupSuggestions(String uid) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/groups/suggestions?uid=$uid'),
        headers: await _getAuthHeaders(),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['groups'] ?? []);
      } else {
        throw Exception('Failed to fetch group suggestions');
      }
    } on TimeoutException {
      throw Exception('Request timeout - please check your internet connection');
    } on SocketException {
      throw Exception('No internet connection available');
    } catch (e) {
      throw Exception('Failed to fetch group suggestions: $e');
    }
  }

  /// Validate group data
  static Map<String, dynamic> validateGroupData(Map<String, dynamic> groupData) {
    final errors = <String, String>{};

    // Validate name
    final name = groupData['name']?.toString().trim();
    if (name == null || name.isEmpty) {
      errors['name'] = 'Group name is required';
    } else if (name.length > MAX_NAME_LENGTH) {
      errors['name'] = 'Group name must be $MAX_NAME_LENGTH characters or less';
    }

    // Validate type
    final type = groupData['type']?.toString();
    if (type != null && !ALLOWED_GROUP_TYPES.contains(type)) {
      errors['type'] = 'Invalid group type. Allowed types: ${ALLOWED_GROUP_TYPES.join(", ")}';
    }

    // Validate description
    final description = groupData['description']?.toString();
    if (description != null && description.length > MAX_DESCRIPTION_LENGTH) {
      errors['description'] = 'Description must be $MAX_DESCRIPTION_LENGTH characters or less';
    }

    // Validate max members
    final maxMembers = groupData['max_members'];
    if (maxMembers != null && (maxMembers < 2 || maxMembers > MAX_MEMBERS)) {
      errors['max_members'] = 'Max members must be between 2 and $MAX_MEMBERS';
    }

    return {
      'valid': errors.isEmpty,
      'errors': errors,
    };
  }

  /// Create a new group
  Future<Map<String, dynamic>> createGroup(Map<String, dynamic> groupData) async {
    // Validate data first
    final validation = validateGroupData(groupData);
    if (!validation['valid']) {
      throw Exception('Validation failed: ${validation['errors']}');
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/groups'),
        headers: await _getAuthHeaders(),
        body: json.encode(groupData),
      ).timeout(_timeout);

      final data = json.decode(response.body);
      if (response.statusCode == 201) {
        notifyListeners();
        return data;
      } else {
        throw Exception(data['error'] ?? 'Failed to create group');
      }
    } on TimeoutException {
      throw Exception('Request timeout - please check your internet connection');
    } on SocketException {
      throw Exception('No internet connection available');
    } catch (e) {
      throw Exception('Failed to create group: $e');
    }
  }

  /// Update a group
  Future<Map<String, dynamic>> updateGroup(String groupId, Map<String, dynamic> groupData) async {
    // Validate data first
    final validation = validateGroupData(groupData);
    if (!validation['valid']) {
      throw Exception('Validation failed: ${validation['errors']}');
    }

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/groups/$groupId'),
        headers: await _getAuthHeaders(),
        body: json.encode(groupData),
      ).timeout(_timeout);

      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        notifyListeners();
        return data;
      } else {
        throw Exception(data['error'] ?? 'Failed to update group');
      }
    } on TimeoutException {
      throw Exception('Request timeout - please check your internet connection');
    } on SocketException {
      throw Exception('No internet connection available');
    } catch (e) {
      throw Exception('Failed to update group: $e');
    }
  }

  /// Delete a group
  Future<Map<String, dynamic>> deleteGroup(String groupId, String uid) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/groups/$groupId'),
        headers: await _getAuthHeaders(),
        body: json.encode({'uid': uid}),
      ).timeout(_timeout);

      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        notifyListeners();
        return data;
      } else {
        throw Exception(data['error'] ?? 'Failed to delete group');
      }
    } on TimeoutException {
      throw Exception('Request timeout - please check your internet connection');
    } on SocketException {
      throw Exception('No internet connection available');
    } catch (e) {
      throw Exception('Failed to delete group: $e');
    }
  }

  /// Get group members
  Future<List<Map<String, dynamic>>> getGroupMembers(String groupId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/groups/$groupId/members'),
        headers: await _getAuthHeaders(),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['members'] ?? []);
      } else {
        final data = json.decode(response.body);
        throw Exception(data['error'] ?? 'Failed to fetch group members');
      }
    } on TimeoutException {
      throw Exception('Request timeout - please check your internet connection');
    } on SocketException {
      throw Exception('No internet connection available');
    } catch (e) {
      throw Exception('Failed to fetch group members: $e');
    }
  }

  /// Cache management
  void _setCacheWithTimer(String key, dynamic data) {
    _groupsCache[key] = data;
    
    // Clear existing timer
    _cacheTimers[key]?.cancel();
    
    // Set new timer
    _cacheTimers[key] = Timer(cacheTimeout, () {
      _groupsCache.remove(key);
      _cacheTimers.remove(key);
    });
  }

  void clearCache() {
    _groupsCache.clear();
    for (final timer in _cacheTimers.values) {
      timer.cancel();
    }
    _cacheTimers.clear();
  }

  @override
  void dispose() {
    clearCache();
    super.dispose();
  }

  /// Get cached groups
  List<Map<String, dynamic>>? getCachedGroups(String key) {
    final cachedData = _groupsCache[key];
    if (cachedData != null && cachedData is List) {
      return List<Map<String, dynamic>>.from(cachedData);
    }
    return null;
  }

  /// Cache groups
  void setCachedGroups(String key, List<Map<String, dynamic>> groups) {
    _setCacheWithTimer(key, groups);
  }

  /// Join group with cache update
  static Future<bool> joinGroupStatic(String groupId, String uid) async {
    try {
      final service = GroupService();
      final response = await http.post(
        Uri.parse('$baseUrl/groups/$groupId/join'),
        headers: await service._getAuthHeaders(),
        body: json.encode({'uid': uid}),
      ).timeout(_timeout);

      return response.statusCode == 200;
    } on TimeoutException {
      throw Exception('Request timeout - please check your internet connection');
    } on SocketException {
      throw Exception('No internet connection available');
    } catch (e) {
      throw Exception('Failed to join group: $e');
    }
  }

  /// Leave group with cache update
  static Future<bool> leaveGroupStatic(String groupId, String uid) async {
    try {
      final service = GroupService();
      final response = await http.post(
        Uri.parse('$baseUrl/groups/$groupId/leave'),
        headers: await service._getAuthHeaders(),
        body: json.encode({'uid': uid}),
      ).timeout(_timeout);

      return response.statusCode == 200;
    } on TimeoutException {
      throw Exception('Request timeout - please check your internet connection');
    } on SocketException {
      throw Exception('No internet connection available');
    } catch (e) {
      throw Exception('Failed to leave group: $e');
    }
  }

  /// Fetch my groups
  static Future<List<Map<String, dynamic>>> fetchMyGroupsStatic(String uid) async {
    try {
      // Create instance to get auth headers
      final service = GroupService();
      final response = await http.get(
        Uri.parse('$baseUrl/groups/my?uid=$uid'),
        headers: await service._getAuthHeaders(),
      ).timeout(_timeout);

      logger.debug('✅ My groups status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        logger.debug('📦 My groups data type: ${data.runtimeType}');
        // Backend returns array directly, not wrapped in 'groups' key
        if (data is List) {
          logger.debug('✅ Got ${data.length} my groups as List');
          return List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data['groups'] != null) {
          logger.debug('✅ Got my groups from Map wrapper');
          return List<Map<String, dynamic>>.from(data['groups']);
        } else {
          logger.debug('⚠️ Unexpected my groups format: $data');
          return [];
        }
      } else {
        final data = json.decode(response.body);
        logger.debug('❌ My groups error: $data');
        throw Exception(data['error'] ?? 'Failed to fetch my groups');
      }
    } on TimeoutException {
      throw Exception('Request timeout - please check your internet connection');
    } on SocketException {
      throw Exception('No internet connection available');
    } catch (e) {
      logger.debug('❌ My groups exception: $e');
      throw Exception('Failed to fetch my groups: $e');
    }
  }

  /// Fetch group by ID
  static Future<Map<String, dynamic>?> fetchGroupByIdStatic(String groupId) async {
    try {
      // Create instance to get auth headers
      final service = GroupService();
      final response = await http.get(
        Uri.parse('$baseUrl/groups/$groupId'),
        headers: await service._getAuthHeaders(),
      ).timeout(_timeout);

      logger.debug('✅ Group details status: ${response.statusCode} for group: $groupId');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        logger.debug('📦 Group details data type: ${data.runtimeType}');
        return data['group'] ?? data;
      } else {
        logger.debug('❌ Group details error: ${response.body}');
        return null;
      }
    } on TimeoutException {
      throw Exception('Request timeout - please check your internet connection');
    } on SocketException {
      throw Exception('No internet connection available');
    } catch (e) {
      logger.debug('❌ Group details exception: $e');
      throw Exception('Failed to fetch group: $e');
    }
  }
}

class GroupServiceException implements Exception {
  final String message;
  final String? code;
  
  const GroupServiceException(this.message, [this.code]);
  
  @override
  String toString() => 'GroupServiceException: $message';
}
