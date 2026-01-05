import 'package:lendly/services/api_client.dart';
import '../config/env_config.dart';

class NotificationService {
  static String get baseUrl => EnvConfig.apiBaseUrl;
  static const Duration timeout = Duration(seconds: 10);

  /// Fetch notifications for a user
  static Future<List<Map<String, dynamic>>> fetchNotifications(String uid) async {
    if (uid.isEmpty) throw ArgumentError('uid cannot be empty');
    
    try {
      final data = await SimpleApiClient.get(
        '/user/notifications',
        queryParams: {'uid': uid},
        requiresAuth: true,
      );
      if (data is Map) {
        return List<Map<String, dynamic>>.from(data['notifications'] ?? []);
      }
      if (data is List) {
        return data.cast<Map<String, dynamic>>();
      }
      return [];
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
      await SimpleApiClient.post(
        '/user/notifications/mark-read',
        body: {
          'uid': uid,
          'notificationId': notificationId,
        },
        requiresAuth: true,
      );
    } catch (e) {
      throw Exception('Error marking notification as read: ${e.toString()}');
    }
  }

  /// Mark all notifications as read
  static Future<void> markAllAsRead(String uid) async {
    if (uid.isEmpty) throw ArgumentError('uid cannot be empty');
    
    try {
      await SimpleApiClient.post(
        '/user/notifications/mark-all-read',
        body: {'uid': uid},
        requiresAuth: true,
      );
    } catch (e) {
      throw Exception('Error marking all notifications as read: ${e.toString()}');
    }
  }

  /// Clear all notifications
  static Future<void> clearAllNotifications(String uid) async {
    if (uid.isEmpty) throw ArgumentError('uid cannot be empty');
    
    try {
      await SimpleApiClient.post(
        '/user/notifications/clear-all',
        body: {'uid': uid},
        requiresAuth: true,
      );
    } catch (e) {
      throw Exception('Error clearing notifications: ${e.toString()}');
    }
  }

  /// Get unread notification count
  static Future<int> getUnreadCount(String uid) async {
    if (uid.isEmpty) throw ArgumentError('uid cannot be empty');
    
    try {
      final data = await SimpleApiClient.get(
        '/user/notifications/unread-count',
        queryParams: {'uid': uid},
        requiresAuth: true,
      );
      if (data is Map) {
        return data['count'] as int? ?? 0;
      }
      return 0;
    } catch (e) {
      throw Exception('Error getting unread count: ${e.toString()}');
    }
  }
}