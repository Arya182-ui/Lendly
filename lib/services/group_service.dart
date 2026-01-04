import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Group management service with error handling and validation
class GroupService {
  static const String baseUrl = 'https://ary-lendly-production.up.railway.app';
  static const _headers = {'Content-Type': 'application/json'};
  static const _timeout = Duration(seconds: 15);

  /// Helper to parse error from response
  static String _parseError(String body, String defaultMsg) {
    try {
      return jsonDecode(body)['error'] ?? defaultMsg;
    } catch (_) {
      return defaultMsg;
    }
  }

  /// Discover groups with optional search query
  static Future<List<Map<String, dynamic>>> fetchDiscoverGroups(
    String uid, {
    String? query,
    int limit = 20,
  }) async {
    if (uid.isEmpty) throw ArgumentError('uid cannot be empty');
    
    try {
      final queryParams = {
        'uid': uid,
        'limit': limit.toString(),
        if (query != null && query.trim().isNotEmpty) 'q': query,
      };
      final url = Uri.parse('$baseUrl/groups/discover').replace(queryParameters: queryParams);
      
      final response = await http.get(url).timeout(_timeout);
      
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      final errorBody = response.body;
      print('Discover groups failed with status ${response.statusCode}: $errorBody');
      throw GroupServiceException(_parseError(response.body, 'Failed to fetch discover groups'));
    } on TimeoutException {
      throw GroupServiceException('Request timed out. Please try again.');
    } on SocketException {
      throw GroupServiceException('No internet connection.');
    }
  }

  /// Discover groups with remote search (alias for backwards compatibility)
  static Future<List<Map<String, dynamic>>> fetchDiscoverGroupsRemote(
    String uid,
    String query, {
    int limit = 20,
  }) async {
    return fetchDiscoverGroups(uid, query: query, limit: limit);
  }

  /// Delete a group (owner only)
  static Future<void> deleteGroup({required String groupId, required String uid}) async {
    if (groupId.isEmpty || uid.isEmpty) {
      throw ArgumentError('groupId and uid cannot be empty');
    }
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/groups/delete'),
        headers: _headers,
        body: jsonEncode({'groupId': groupId, 'uid': uid}),
      ).timeout(_timeout);
      
      if (response.statusCode != 200) {
        throw GroupServiceException(_parseError(response.body, 'Failed to delete group'));
      }
    } on TimeoutException {
      throw GroupServiceException('Request timed out. Please try again.');
    } on SocketException {
      throw GroupServiceException('No internet connection.');
    }
  }

  /// Update group details
  static Future<void> updateGroup({
    required String groupId,
    required String name,
    required String description,
    String? uid,
  }) async {
    if (groupId.isEmpty) throw ArgumentError('groupId cannot be empty');
    if (name.trim().isEmpty) throw ArgumentError('name cannot be empty');
    if (name.length > 100) throw ArgumentError('name too long (max 100 characters)');
    if (description.length > 500) throw ArgumentError('description too long (max 500 characters)');
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/groups/update'),
        headers: _headers,
        body: jsonEncode({
          'groupId': groupId,
          'name': name.trim(),
          'description': description.trim(),
          if (uid != null) 'uid': uid,
        }),
      ).timeout(_timeout);
      
      if (response.statusCode != 200) {
        throw GroupServiceException(_parseError(response.body, 'Failed to update group'));
      }
    } on TimeoutException {
      throw GroupServiceException('Request timed out. Please try again.');
    } on SocketException {
      throw GroupServiceException('No internet connection.');
    }
  }

  /// Create a new group
  static Future<Map<String, dynamic>?> createGroup({
    required String name,
    required String type,
    required String description,
    required String createdBy,
  }) async {
    if (name.trim().isEmpty) throw ArgumentError('name cannot be empty');
    if (name.length > 100) throw ArgumentError('name too long (max 100 characters)');
    if (type.isEmpty) throw ArgumentError('type cannot be empty');
    if (createdBy.isEmpty) throw ArgumentError('createdBy cannot be empty');
    if (description.length > 500) throw ArgumentError('description too long (max 500 characters)');
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/groups/create'),
        headers: _headers,
        body: jsonEncode({
          'name': name.trim(),
          'type': type,
          'description': description.trim(),
          'createdBy': createdBy,
        }),
      ).timeout(_timeout);
      
      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      }
      final errorBody = response.body;
      print('Group creation failed with status ${response.statusCode}: $errorBody');
      throw GroupServiceException(_parseError(response.body, 'Failed to create group'));
    } on TimeoutException {
      throw GroupServiceException('Request timed out. Please try again.');
    } on SocketException {
      throw GroupServiceException('No internet connection.');
    }
  }

  /// Join a group
  static Future<void> joinGroup({required String groupId, required String uid}) async {
    if (groupId.isEmpty || uid.isEmpty) {
      throw ArgumentError('groupId and uid cannot be empty');
    }
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/groups/join'),
        headers: _headers,
        body: jsonEncode({'groupId': groupId, 'uid': uid}),
      ).timeout(_timeout);
      
      if (response.statusCode != 200) {
        throw GroupServiceException(_parseError(response.body, 'Failed to join group'));
      }
    } on TimeoutException {
      throw GroupServiceException('Request timed out. Please try again.');
    } on SocketException {
      throw GroupServiceException('No internet connection.');
    }
  }

  /// Leave a group
  static Future<void> leaveGroup({required String groupId, required String uid}) async {
    if (groupId.isEmpty || uid.isEmpty) {
      throw ArgumentError('groupId and uid cannot be empty');
    }
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/groups/leave'),
        headers: _headers,
        body: jsonEncode({'groupId': groupId, 'uid': uid}),
      ).timeout(_timeout);
      
      if (response.statusCode != 200) {
        throw GroupServiceException(_parseError(response.body, 'Failed to leave group'));
      }
    } on TimeoutException {
      throw GroupServiceException('Request timed out. Please try again.');
    } on SocketException {
      throw GroupServiceException('No internet connection.');
    }
  }

  /// Fetch user's groups
  static Future<List<Map<String, dynamic>>> fetchMyGroups(String uid) async {
    if (uid.isEmpty) throw ArgumentError('uid cannot be empty');
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/groups/my?uid=$uid'),
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      throw GroupServiceException(_parseError(response.body, 'Failed to fetch groups'));
    } on TimeoutException {
      throw GroupServiceException('Request timed out. Please try again.');
    } on SocketException {
      throw GroupServiceException('No internet connection.');
    }
  }

  /// Fetch group by ID
  static Future<Map<String, dynamic>> fetchGroupById(String groupId) async {
    if (groupId.isEmpty) throw ArgumentError('groupId cannot be empty');
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/groups/$groupId'),
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw GroupServiceException(_parseError(response.body, 'Failed to fetch group'));
    } on TimeoutException {
      throw GroupServiceException('Request timed out. Please try again.');
    } on SocketException {
      throw GroupServiceException('No internet connection.');
    }
  }

}

/// Custom exception for group service errors
class GroupServiceException implements Exception {
  final String message;
  GroupServiceException(this.message);
  
  @override
  String toString() => message;
}
