import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/env_config.dart';

class ChallengesService {
  static const String _baseUrl = 'challenges';
  
  // Get daily challenge for user
  static Future<Map<String, dynamic>> getDailyChallenge(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${EnvConfig.apiBaseUrl}/$_baseUrl/daily'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to fetch daily challenge: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Complete daily challenge
  static Future<Map<String, dynamic>> completeChallenge(String token) async {
    try {
      final response = await http.post(
        Uri.parse('${EnvConfig.apiBaseUrl}/$_baseUrl/complete'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to complete challenge: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get challenge history
  static Future<Map<String, dynamic>> getChallengeHistory(
    String token, {
    int limit = 10,
    String? startAfter,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
      };
      
      if (startAfter != null) {
        queryParams['startAfter'] = startAfter;
      }

      final uri = Uri.parse('${EnvConfig.apiBaseUrl}/$_baseUrl/history')
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
        throw Exception('Failed to fetch challenge history: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Parse challenge data for UI
  static Map<String, dynamic> parseChallengeForUI(Map<String, dynamic> challengeData) {
    final challenge = challengeData['challenge'] ?? {};
    
    return {
      'title': challenge['title'] ?? 'Daily Challenge',
      'description': challenge['description'] ?? 'Complete your daily challenge',
      'reward': challenge['reward'] ?? 0,
      'progress': challenge['progress'] ?? 0,
      'target': challenge['target'] ?? 1,
      'completed': challenge['completed'] ?? false,
      'canClaim': challenge['canClaim'] ?? false,
      'type': challenge['type'] ?? 'general',
      'progressPercentage': challenge['target'] > 0 
          ? (challenge['progress'] / challenge['target'] * 100).clamp(0, 100).toDouble()
          : 0.0,
    };
  }

  // Get challenge icon based on type
  static String getChallengeIcon(String type) {
    switch (type) {
      case 'list_item':
        return '📦';
      case 'complete_transaction':
        return '🤝';
      case 'social_connect':
        return '👥';
      case 'share_impact':
        return '🌟';
      case 'explore_categories':
        return '🔍';
      default:
        return '🎯';
    }
  }

  // Get challenge color based on type
  static int getChallengeColor(String type) {
    switch (type) {
      case 'list_item':
        return 0xFF4CAF50; // Green
      case 'complete_transaction':
        return 0xFF2196F3; // Blue
      case 'social_connect':
        return 0xFF9C27B0; // Purple
      case 'share_impact':
        return 0xFFFF9800; // Orange
      case 'explore_categories':
        return 0xFFE91E63; // Pink
      default:
        return 0xFF607D8B; // Blue Grey
    }
  }
}