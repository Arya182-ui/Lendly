import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/env_config.dart';

class RatingService {
  static String get baseUrl => EnvConfig.apiBaseUrl;
  static const Duration timeout = Duration(seconds: 10);

  /// Submit a rating for a user
  static Future<Map<String, dynamic>> submitRating({
    required String fromUid,
    required String toUid,
    required int rating,
    String? review,
    String? transactionId,
  }) async {
    if (fromUid.isEmpty || toUid.isEmpty) {
      throw ArgumentError('fromUid and toUid cannot be empty');
    }
    if (rating < 1 || rating > 5) {
      throw ArgumentError('Rating must be between 1 and 5');
    }
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/user/submit-rating'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fromUid': fromUid,
          'toUid': toUid,
          'rating': rating,
          'review': review,
          'transactionId': transactionId,
        }),
      ).timeout(timeout);
      
      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['error'] ?? 'Failed to submit rating');
      }
    } catch (e) {
      throw Exception('Error submitting rating: ${e.toString()}');
    }
  }

  /// Get ratings for a user
  static Future<List<Map<String, dynamic>>> getRatings(String uid, {int limit = 20}) async {
    if (uid.isEmpty) throw ArgumentError('uid cannot be empty');
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user/ratings?uid=$uid&limit=$limit'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['ratings'] ?? []);
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['error'] ?? 'Failed to fetch ratings');
      }
    } catch (e) {
      throw Exception('Error fetching ratings: ${e.toString()}');
    }
  }

  /// Get user's trust score and rating summary
  static Future<Map<String, dynamic>> getUserRatingSummary(String uid) async {
    if (uid.isEmpty) throw ArgumentError('uid cannot be empty');
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user/public-profile?uid=$uid'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'rating': data['rating'] ?? 0.0,
          'totalRatings': data['totalRatings'] ?? 0,
          'trustScore': data['trustScore'] ?? 0,
        };
      } else {
        return {
          'rating': 0.0,
          'totalRatings': 0,
          'trustScore': 0,
        };
      }
    } catch (e) {
      return {
        'rating': 0.0,
        'totalRatings': 0,
        'trustScore': 0,
      };
    }
  }

  /// Check if user can rate another user (for a transaction)
  static Future<bool> canRateUser({
    required String fromUid,
    required String toUid,
    String? transactionId,
  }) async {
    if (fromUid.isEmpty || toUid.isEmpty) return false;
    if (fromUid == toUid) return false;
    
    // For now, allow rating if users are different
    // In production, you might want to check if they had a transaction
    return true;
  }
}