import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:async';
import '../config/env_config.dart';

/// Service for student ID verification
class VerificationService {
  static String get baseUrl => EnvConfig.apiBaseUrl;
  static const _timeout = Duration(seconds: 30); // Longer for file uploads
  static const _maxFileSize = 5 * 1024 * 1024; // 5MB
  static const _allowedExtensions = ['jpg', 'jpeg', 'png', 'pdf'];

  /// Upload student ID for verification
  static Future<Map<String, dynamic>> uploadStudentId({
    required String uid,
    required File file,
  }) async {
    // Input validation
    if (uid.isEmpty) {
      return {'success': false, 'error': 'User ID is required'};
    }
    
    if (!await file.exists()) {
      return {'success': false, 'error': 'File does not exist'};
    }
    
    final fileSize = await file.length();
    if (fileSize > _maxFileSize) {
      return {'success': false, 'error': 'File too large (max 5MB)'};
    }
    
    final extension = file.path.split('.').last.toLowerCase();
    if (!_allowedExtensions.contains(extension)) {
      return {'success': false, 'error': 'Invalid file type. Allowed: JPG, PNG, PDF'};
    }

    try {
      var uri = Uri.parse('$baseUrl/auth/verify-student');
      var request = http.MultipartRequest('POST', uri)
        ..fields['uid'] = uid
        ..files.add(await http.MultipartFile.fromPath('file', file.path));
      
      var streamedResponse = await request.send().timeout(_timeout);
      var response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'error': 'Failed to upload ID. Please try again later.'
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'error': 'Upload timed out. Please try again.'
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
        'error': 'Unexpected error: ${e.toString()}'
      };
    }
  }

  /// Get verification status for a user
  static Future<Map<String, dynamic>> getVerificationStatus(String uid) async {
    if (uid.isEmpty) {
      return {'success': false, 'error': 'User ID is required'};
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user/$uid/verification-status'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'error': 'Failed to get verification status'
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'error': 'Request timed out. Please try again.'
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e'
      };
    }
  }

  /// Get verification requirements
  static Future<Map<String, dynamic>> getVerificationRequirements() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/verification-requirements'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'error': 'Failed to get requirements'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to load requirements'
      };
    }
  }
}
