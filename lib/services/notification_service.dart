import 'dart:convert';
import 'package:http/http.dart' as http;

class NotificationService {
  static const String baseUrl = 'https://ary-lendly-production.up.railway.app';
  static const Duration timeout = Duration(seconds: 10);

  /// Fetch notifications for a user
  static Future<List<Map<String, dynamic>>> fetchNotifications(String uid) async {
    if (uid.isEmpty) throw ArgumentError('uid cannot be empty');
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user/notifications?uid=$uid'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['notifications'] ?? []);
      }
      throw Exception('Failed to fetch notifications: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error fetching notifications: ${e.toString()}');
    }
  }

  /// Mark notification as read
  static Future<void> markAsRead(String uid, String notificationId) async {
    if (uid.isEmpty || notificationId.isEmpty) {
      throw ArgumentError('uid and notificationId cannot be empty');
    }
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/user/notifications/mark-read'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'uid': uid,
          'notificationId': notificationId,
        }),
      ).timeout(timeout);
      
      if (response.statusCode != 200) {
        throw Exception('Failed to mark notification as read');
      }
    } catch (e) {
      throw Exception('Error marking notification as read: ${e.toString()}');
    }
  }

  /// Mark all notifications as read
  static Future<void> markAllAsRead(String uid) async {
    if (uid.isEmpty) throw ArgumentError('uid cannot be empty');
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/user/notifications/mark-all-read'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'uid': uid}),
      ).timeout(timeout);
      
      if (response.statusCode != 200) {
        throw Exception('Failed to mark all notifications as read');
      }
    } catch (e) {
      throw Exception('Error marking all notifications as read: ${e.toString()}');
    }
  }

  /// Clear all notifications
  static Future<void> clearAllNotifications(String uid) async {
    if (uid.isEmpty) throw ArgumentError('uid cannot be empty');
    
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/user/notifications/clear-all'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'uid': uid}),
      ).timeout(timeout);
      
      if (response.statusCode != 200) {
        throw Exception('Failed to clear notifications');
      }
    } catch (e) {
      throw Exception('Error clearing notifications: ${e.toString()}');
    }
  }

  /// Get unread notification count
  static Future<int> getUnreadCount(String uid) async {
    if (uid.isEmpty) throw ArgumentError('uid cannot be empty');
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user/notifications/unread-count?uid=$uid'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['count'] ?? 0;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }
}