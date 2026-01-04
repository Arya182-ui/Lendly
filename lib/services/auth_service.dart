import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Authentication and friend-related API service
class AuthService {
  static const String baseUrl = 'https://ary-lendly-production.up.railway.app';
  static const _headers = {'Content-Type': 'application/json'};
  static const _timeout = Duration(seconds: 15);

  /// Helper method for POST requests with error handling
  static Future<Map<String, dynamic>> _post(String endpoint, Map<String, dynamic> body) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(_timeout);
      
      final data = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return data is Map<String, dynamic> ? data : {'success': true, 'data': data};
      }
      return {'success': false, 'error': data['error'] ?? 'Request failed'};
    } on TimeoutException {
      return {'success': false, 'error': 'Request timed out. Please try again.'};
    } on SocketException {
      return {'success': false, 'error': 'No internet connection.'};
    } on FormatException {
      return {'success': false, 'error': 'Invalid response from server.'};
    } catch (e) {
      return {'success': false, 'error': 'Network error. Please check your connection.'};
    }
  }

  /// Helper method for GET requests with error handling
  static Future<Map<String, dynamic>> _get(String endpoint) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
      ).timeout(_timeout);
      
      final data = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return data is Map<String, dynamic> ? data : {'success': true, 'data': data};
      }
      return {'success': false, 'error': data['error'] ?? 'Request failed'};
    } on TimeoutException {
      return {'success': false, 'error': 'Request timed out. Please try again.'};
    } on SocketException {
      return {'success': false, 'error': 'No internet connection.'};
    } catch (e) {
      return {'success': false, 'error': 'Network error. Please check your connection.'};
    }
  }

  // ============ Friend Request Methods ============
  
  static Future<Map<String, dynamic>> sendFriendRequest(String fromUid, String toUid) async {
    if (fromUid.isEmpty || toUid.isEmpty) {
      return {'success': false, 'error': 'Invalid user IDs'};
    }
    if (fromUid == toUid) {
      return {'success': false, 'error': 'Cannot send friend request to yourself'};
    }
    return _post('/user/send-friend-request', {'fromUid': fromUid, 'toUid': toUid});
  }

  static Future<Map<String, dynamic>> acceptFriendRequest(String fromUid, String toUid) async {
    if (fromUid.isEmpty || toUid.isEmpty) {
      return {'success': false, 'error': 'Invalid user IDs'};
    }
    return _post('/user/accept-friend-request', {'fromUid': fromUid, 'toUid': toUid});
  }

  static Future<Map<String, dynamic>> getFriendshipStatus(String uid1, String uid2) async {
    if (uid1.isEmpty || uid2.isEmpty) {
      return {'success': false, 'error': 'Invalid user IDs'};
    }
    return _get('/user/friendship-status?uid1=$uid1&uid2=$uid2');
  }

  static Future<Map<String, dynamic>> getOrCreateChat(String uid1, String uid2) async {
    if (uid1.isEmpty || uid2.isEmpty) {
      return {'success': false, 'error': 'Invalid user IDs'};
    }
    return _post('/user/get-or-create-chat', {'uid1': uid1, 'uid2': uid2});
  }

  // ============ Authentication Methods ============
  
  static Future<Map<String, dynamic>> loginWithPassword(String email, String password) async {
    if (!_isValidEmail(email)) {
      return {'success': false, 'error': 'Invalid email format'};
    }
    if (password.isEmpty) {
      return {'success': false, 'error': 'Password is required'};
    }
    return _post('/auth/login', {'email': email, 'password': password});
  }

  static Future<Map<String, dynamic>> sendOtp(String email) async {
    if (!_isValidEmail(email)) {
      return {'success': false, 'error': 'Invalid email format'};
    }
    return _post('/auth/send-otp', {'email': email});
  }

  static Future<Map<String, dynamic>> loginWithOtp(String email, String otp, String otpId) async {
    if (!_isValidEmail(email)) {
      return {'success': false, 'error': 'Invalid email format'};
    }
    if (otp.length != 6) {
      return {'success': false, 'error': 'OTP must be 6 digits'};
    }
    return _post('/auth/login-otp', {'email': email, 'otp': otp, 'otpId': otpId});
  }

  static Future<Map<String, dynamic>> verifyOtp(String email, String otp, String otpId) async {
    if (!_isValidEmail(email)) {
      return {'success': false, 'error': 'Invalid email format'};
    }
    if (otp.length != 6) {
      return {'success': false, 'error': 'OTP must be 6 digits'};
    }
    return _post('/auth/verify-otp', {'email': email, 'otp': otp, 'otpId': otpId});
  }

  static Future<Map<String, dynamic>> resendOtp(String email) async {
    if (!_isValidEmail(email)) {
      return {'success': false, 'error': 'Invalid email format'};
    }
    return _post('/auth/resend-otp', {'email': email});
  }

  static Future<Map<String, dynamic>> completeOnboarding(String uid) async {
    if (uid.isEmpty) {
      return {'success': false, 'error': 'User ID is required'};
    }
    return _post('/auth/complete-onboarding', {'uid': uid});
  }

  static Future<Map<String, dynamic>> setPassword(String uid, String password) async {
    if (uid.isEmpty) {
      return {'success': false, 'error': 'User ID is required'};
    }
    if (password.length < 6) {
      return {'success': false, 'error': 'Password must be at least 6 characters'};
    }
    return _post('/auth/set-password', {'uid': uid, 'password': password});
  }

  /// Validate email format
  static bool _isValidEmail(String email) {
    return RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$').hasMatch(email);
  }
}
