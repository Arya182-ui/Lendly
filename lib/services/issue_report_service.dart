import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Service for submitting issue reports
class IssueReportService {
  static const String baseUrl = 'https://ary-lendly-production.up.railway.app';
  static const _timeout = Duration(seconds: 12);
  static const _maxMessageLength = 5000;

  /// Validate email format
  static bool _isValidEmail(String email) {
    return RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$').hasMatch(email);
  }

  /// Submit an issue report
  static Future<Map<String, dynamic>> submitIssue({
    required String uid,
    required String email,
    required String message,
  }) async {
    // Input validation
    if (uid.isEmpty) {
      return {'success': false, 'error': 'User ID is required'};
    }
    if (!_isValidEmail(email)) {
      return {'success': false, 'error': 'Invalid email format'};
    }
    if (message.trim().isEmpty) {
      return {'success': false, 'error': 'Message cannot be empty'};
    }
    if (message.length > _maxMessageLength) {
      return {'success': false, 'error': 'Message too long (max $_maxMessageLength characters)'};
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/report-issue'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'uid': uid,
          'email': email.trim(),
          'message': message.trim(),
        }),
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'error': 'Failed to submit issue. Please try again later.'
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'error': 'Request timed out. Please try again.'
      };
    } on SocketException {
      return {
        'success': false,
        'error': 'No internet connection. Please check your network.'
      };
    } on http.ClientException {
      return {
        'success': false,
        'error': 'Network error. Please check your connection.'
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'An unexpected error occurred. Please try again.'
      };
    }
  }
}
