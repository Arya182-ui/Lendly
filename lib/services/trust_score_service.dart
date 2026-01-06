import 'dart:convert';
import 'package:http/http.dart' as http;
import 'firebase_auth_service.dart';
import '../config/env_config.dart';

class TrustScoreService {
  // Use environment configuration for base URL
  static String get baseUrl => EnvConfig.socketUrl;

  /// Get user's trust score details with tier and history
  static Future<Map<String, dynamic>> getTrustScore(String uid) async {
    try {
      final authService = FirebaseAuthService();
      final token = await authService.getIdToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/user/$uid/trust-score'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('[TRUST_SCORE] Response: ${response.statusCode} ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'trustScore': data['trustScore'] ?? {},
          'history': data['history'] ?? [],
        };
      } else {
        print('[TRUST_SCORE] Error: ${response.body}');
        return {
          'success': false,
          'error': 'Failed to fetch trust score'
        };
      }
    } catch (e) {
      print('[TRUST_SCORE] Exception: $e');
      return {
        'success': false,
        'error': e.toString()
      };
    }
  }

  /// Get tier information from score
  static Map<String, dynamic> getTierFromScore(int score) {
    if (score >= 90) {
      return {
        'tier': 'Excellent',
        'badge': '🏆',
        'color': 0xFFFFD700, // Gold
        'description': 'Top-tier trusted member'
      };
    } else if (score >= 70) {
      return {
        'tier': 'Good',
        'badge': '⭐',
        'color': 0xFFC0C0C0, // Silver
        'description': 'Reliable community member'
      };
    } else if (score >= 50) {
      return {
        'tier': 'Average',
        'badge': '🥉',
        'color': 0xFFCD7F32, // Bronze
        'description': 'Building reputation'
      };
    } else if (score >= 30) {
      return {
        'tier': 'Below Average',
        'badge': '⚠️',
        'color': 0xFFFFA500, // Orange
        'description': 'Needs improvement'
      };
    } else {
      return {
        'tier': 'Poor',
        'badge': '❌',
        'color': 0xFFFF0000, // Red
        'description': 'Limited access'
      };
    }
  }

  /// Format trust score change for display
  static String formatScoreChange(num change) {
    if (change > 0) {
      return '+${change.toStringAsFixed(1)}';
    } else {
      return change.toStringAsFixed(1);
    }
  }

  /// Get color for score change
  static int getChangeColor(num change) {
    if (change > 0) {
      return 0xFF4CAF50; // Green
    } else if (change < 0) {
      return 0xFFF44336; // Red
    } else {
      return 0xFF9E9E9E; // Grey
    }
  }
}
