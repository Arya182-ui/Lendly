import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/env_config.dart';

class ActivitiesService {
  static const String _baseUrl = 'activities';
  
  // Get campus activity feed
  static Future<Map<String, dynamic>> getCampusActivities(
    String token, {
    int limit = 20,
    String? startAfter,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
      };
      
      if (startAfter != null) {
        queryParams['startAfter'] = startAfter;
      }

      final uri = Uri.parse('${EnvConfig.apiBaseUrl}/$_baseUrl/campus')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to fetch campus activities: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get trending activities
  static Future<Map<String, dynamic>> getTrendingActivities(
    String token, {
    String timeframe = '24h',
  }) async {
    try {
      final queryParams = <String, String>{
        'timeframe': timeframe,
      };

      final uri = Uri.parse('${EnvConfig.apiBaseUrl}/$_baseUrl/trending')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to fetch trending activities: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Create new activity
  static Future<Map<String, dynamic>> createActivity(
    String token, {
    required String type,
    required String title,
    String? description,
    Map<String, dynamic>? metadata,
    String visibility = 'campus',
  }) async {
    try {
      final body = {
        'type': type,
        'title': title,
        'description': description,
        'metadata': metadata,
        'visibility': visibility,
      };

      final response = await http.post(
        Uri.parse('${EnvConfig.apiBaseUrl}/$_baseUrl/create'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to create activity: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Like/unlike activity
  static Future<Map<String, dynamic>> toggleLike(
    String token,
    String activityId,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('${EnvConfig.apiBaseUrl}/$_baseUrl/$activityId/like'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to toggle like: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get user activities
  static Future<Map<String, dynamic>> getUserActivities(
    String token, {
    int limit = 20,
    String? startAfter,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
      };
      
      if (startAfter != null) {
        queryParams['startAfter'] = startAfter;
      }

      final uri = Uri.parse('${EnvConfig.apiBaseUrl}/$_baseUrl/user')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to fetch user activities: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Parse activity data for UI
  static Map<String, dynamic> parseActivityForUI(Map<String, dynamic> activityData) {
    final user = activityData['user'] ?? {};
    
    return {
      'id': activityData['id'] ?? '',
      'type': activityData['type'] ?? 'general',
      'title': activityData['title'] ?? 'Activity',
      'description': activityData['description'] ?? '',
      'timestamp': activityData['timestamp'],
      'likes': activityData['likes'] ?? 0,
      'comments': activityData['comments'] ?? 0,
      'shares': activityData['shares'] ?? 0,
      'engagementScore': activityData['engagementScore'] ?? 0,
      'user': {
        'name': user['name'] ?? 'Anonymous',
        'avatar': user['avatar'],
        'trustScore': user['trustScore'] ?? 0,
        'college': user['college'] ?? '',
      },
      'metadata': activityData['metadata'] ?? {},
    };
  }

  // Get activity icon based on type
  static String getActivityIcon(String type) {
    switch (type) {
      case 'item_listed':
        return '📦';
      case 'transaction_completed':
        return '🤝';
      case 'challenge_completed':
        return '🏆';
      case 'group_joined':
        return '👥';
      case 'impact_shared':
        return '🌟';
      case 'achievement_unlocked':
        return '🎖️';
      case 'milestone_reached':
        return '🎯';
      case 'friend_added':
        return '👋';
      default:
        return '📱';
    }
  }

  // Get activity color based on type
  static int getActivityColor(String type) {
    switch (type) {
      case 'item_listed':
        return 0xFF4CAF50; // Green
      case 'transaction_completed':
        return 0xFF2196F3; // Blue
      case 'challenge_completed':
        return 0xFFFF9800; // Orange
      case 'group_joined':
        return 0xFF9C27B0; // Purple
      case 'impact_shared':
        return 0xFFE91E63; // Pink
      case 'achievement_unlocked':
        return 0xFFFFD700; // Gold
      case 'milestone_reached':
        return 0xFF00BCD4; // Cyan
      case 'friend_added':
        return 0xFF8BC34A; // Light Green
      default:
        return 0xFF607D8B; // Blue Grey
    }
  }

  // Format timestamp for display
  static String formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Just now';
    
    try {
      DateTime dateTime;
      if (timestamp is String) {
        dateTime = DateTime.parse(timestamp);
      } else if (timestamp is Map && timestamp['_seconds'] != null) {
        // Firestore timestamp
        dateTime = DateTime.fromMillisecondsSinceEpoch(
          timestamp['_seconds'] * 1000 + (timestamp['_nanoseconds'] ?? 0) ~/ 1000000
        );
      } else {
        return 'Just now';
      }
      
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      
      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inDays < 1) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${difference.inDays ~/ 7}w ago';
      }
    } catch (e) {
      return 'Just now';
    }
  }
}