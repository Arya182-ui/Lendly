import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import 'firebase_auth_service.dart';
import 'firebase_auth_service.dart';

// Enhanced notification models
class AppNotification {
  final String id;
  final String uid;
  final String type;
  final String title;
  final String message;
  final Map<String, dynamic>? data;
  final bool read;
  final DateTime createdAt;
  final String? actionUrl;
  final List<NotificationAction>? actions;
  final String? icon;
  final NotificationPriority priority;

  AppNotification({
    required this.id,
    required this.uid,
    required this.type,
    required this.title,
    required this.message,
    this.data,
    required this.read,
    required this.createdAt,
    this.actionUrl,
    this.actions,
    this.icon,
    this.priority = NotificationPriority.normal,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] ?? '',
      uid: json['uid'] ?? '',
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      data: json['data'],
      read: json['read'] ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      actionUrl: json['actionUrl'],
      actions: json['actions'] != null 
        ? (json['actions'] as List).map((a) => NotificationAction.fromJson(a)).toList()
        : null,
      icon: json['icon'],
      priority: NotificationPriority.values.firstWhere(
        (p) => p.name == json['priority'],
        orElse: () => NotificationPriority.normal,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uid': uid,
      'type': type,
      'title': title,
      'message': message,
      'data': data,
      'read': read,
      'createdAt': createdAt.toIso8601String(),
      'actionUrl': actionUrl,
      'actions': actions?.map((a) => a.toJson()).toList(),
      'icon': icon,
      'priority': priority.name,
    };
  }

  AppNotification copyWith({
    String? id,
    String? uid,
    String? type,
    String? title,
    String? message,
    Map<String, dynamic>? data,
    bool? read,
    DateTime? createdAt,
    String? actionUrl,
    List<NotificationAction>? actions,
    String? icon,
    NotificationPriority? priority,
  }) {
    return AppNotification(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      data: data ?? this.data,
      read: read ?? this.read,
      createdAt: createdAt ?? this.createdAt,
      actionUrl: actionUrl ?? this.actionUrl,
      actions: actions ?? this.actions,
      icon: icon ?? this.icon,
      priority: priority ?? this.priority,
    );
  }
}

class NotificationAction {
  final String id;
  final String label;
  final String action;
  final Map<String, dynamic>? data;
  final bool primary;

  NotificationAction({
    required this.id,
    required this.label,
    required this.action,
    this.data,
    this.primary = false,
  });

  factory NotificationAction.fromJson(Map<String, dynamic> json) {
    return NotificationAction(
      id: json['id'] ?? '',
      label: json['label'] ?? '',
      action: json['action'] ?? '',
      data: json['data'],
      primary: json['primary'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'action': action,
      'data': data,
      'primary': primary,
    };
  }
}

class NotificationCategory {
  final String type;
  final String label;
  final String icon;

  NotificationCategory({
    required this.type,
    required this.label,
    required this.icon,
  });

  factory NotificationCategory.fromJson(Map<String, dynamic> json) {
    return NotificationCategory(
      type: json['type'] ?? '',
      label: json['label'] ?? '',
      icon: json['icon'] ?? '',
    );
  }
}

class NotificationPagination {
  final int limit;
  final int offset;
  final int total;
  final int unread;
  final bool hasMore;

  NotificationPagination({
    required this.limit,
    required this.offset,
    required this.total,
    required this.unread,
    required this.hasMore,
  });

  factory NotificationPagination.fromJson(Map<String, dynamic> json) {
    return NotificationPagination(
      limit: json['limit'] ?? 0,
      offset: json['offset'] ?? 0,
      total: json['total'] ?? 0,
      unread: json['unread'] ?? 0,
      hasMore: json['hasMore'] ?? false,
    );
  }
}

enum NotificationPriority { low, normal, high, urgent }

class NotificationFilter {
  final String? type;
  final bool? unreadOnly;
  final NotificationPriority? priority;

  NotificationFilter({
    this.type,
    this.unreadOnly,
    this.priority,
  });

  Map<String, String> toQueryParams() {
    final params = <String, String>{};
    if (type != null) params['type'] = type!;
    if (unreadOnly != null) params['unreadOnly'] = unreadOnly.toString();
    if (priority != null) params['priority'] = priority!.name;
    return params;
  }
}

class EnhancedNotificationService extends ChangeNotifier {
  static const String _cacheKey = 'notifications_cache';
  static const String _unreadCountKey = 'unread_count_cache';
  static const Duration _cacheValidityDuration = Duration(minutes: 5);

  final FirebaseAuthService _authService = FirebaseAuthService();

  List<AppNotification> _notifications = [];
  List<NotificationCategory> _categories = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _error;
  NotificationPagination? _pagination;
  Timer? _refreshTimer;

  /// Get headers with authentication token
  Future<Map<String, String>> _getAuthHeaders() async {
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
    };
    
    try {
      final token = await _authService.getIdToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    } catch (e) {
      debugPrint('Failed to get auth token: $e');
    }
    
    return headers;
  }

  // Getters
  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  List<NotificationCategory> get categories => List.unmodifiable(_categories);
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get error => _error;
  NotificationPagination? get pagination => _pagination;

  // Filtered notifications
  List<AppNotification> getFilteredNotifications(NotificationFilter? filter) {
    if (filter == null) return notifications;
    
    return _notifications.where((notification) {
      if (filter.type != null && notification.type != filter.type) {
        return false;
      }
      if (filter.unreadOnly == true && notification.read) {
        return false;
      }
      if (filter.priority != null && notification.priority != filter.priority) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Fetch notifications for a user
  Future<List<Map<String, dynamic>>> fetchNotifications(String uid) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/user/notifications?uid=$uid'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['notifications'] ?? []);
      } else {
        throw Exception('Failed to fetch notifications: \${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Request timeout - please check your internet connection');
    } on SocketException {
      throw Exception('No internet connection available');
    } catch (e) {
      throw Exception('Failed to fetch notifications: \$e');
    }
  }

  /// Mark a notification as read
  Future<void> markAsRead(String uid, String notificationId) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/user/notifications/mark-read'),
        headers: headers,
        body: json.encode({'uid': uid, 'notificationId': notificationId}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('Failed to mark notification as read: \${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Request timeout - please check your internet connection');
    } on SocketException {
      throw Exception('No internet connection available');
    } catch (e) {
      throw Exception('Failed to mark notification as read: \$e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead(String uid) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/user/notifications/mark-all-read'),
        headers: headers,
        body: json.encode({'uid': uid}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('Failed to mark all notifications as read: \${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Request timeout - please check your internet connection');
    } on SocketException {
      throw Exception('No internet connection available');
    } catch (e) {
      throw Exception('Failed to mark all notifications as read: \$e');
    }
  }

  /// Clear all notifications
  Future<void> clearAllNotifications(String uid) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/user/notifications/clear-all'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'uid': uid}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('Failed to clear notifications: \${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Request timeout - please check your internet connection');
    } on SocketException {
      throw Exception('No internet connection available');
    } catch (e) {
      throw Exception('Failed to clear notifications: \$e');
    }
  }

  // Get notifications by type
  List<AppNotification> getNotificationsByType(String type) {
    return _notifications.where((n) => n.type == type).toList();
  }

  // Get unread notifications
  List<AppNotification> get unreadNotifications {
    return _notifications.where((n) => !n.read).toList();
  }

  // Initialize service
  Future<void> initialize(String uid) async {
    await _loadCachedData();
    await loadCategories();
    await loadNotifications(uid);
    _startPeriodicRefresh(uid);
  }

  // Load notification categories
  Future<void> loadCategories() async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/user/notifications/categories');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          _categories = (data['categories'] as List)
              .map((category) => NotificationCategory.fromJson(category))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }

  // Load notifications with filtering and pagination
  Future<void> loadNotifications(
    String uid, {
    NotificationFilter? filter,
    int limit = 50,
    int offset = 0,
    bool append = false,
  }) async {
    if (_isLoading && !append) return;

    _setLoading(true);
    _setError(null);

    try {
      final queryParams = <String, String>{
        'uid': uid,
        'limit': limit.toString(),
        'offset': offset.toString(),
        ...(filter?.toQueryParams() ?? {}),
      };

      final uri = Uri.parse('${ApiConfig.baseUrl}/user/notifications')
          .replace(queryParameters: queryParams);
      
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          final newNotifications = (data['notifications'] as List)
              .map((notif) => AppNotification.fromJson(notif))
              .toList();
          
          if (append) {
            _notifications.addAll(newNotifications);
          } else {
            _notifications = newNotifications;
          }
          
          _pagination = NotificationPagination.fromJson(data['pagination']);
          _unreadCount = _pagination?.unread ?? 0;
          
          // Cache data
          await _cacheData();
          notifyListeners();
        } else {
          _setError(data['error'] ?? 'Failed to load notifications');
        }
      } else {
        _setError('Failed to load notifications');
      }
    } catch (e) {
      _setError('Network error: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Load more notifications (pagination)
  Future<void> loadMoreNotifications(
    String uid, {
    NotificationFilter? filter,
  }) async {
    if (_pagination?.hasMore != true || _isLoading) return;
    
    await loadNotifications(
      uid,
      filter: filter,
      offset: _notifications.length,
      append: true,
    );
  }

  // Refresh notifications
  Future<void> refreshNotifications(String uid, {NotificationFilter? filter}) async {
    await loadNotifications(uid, filter: filter);
  }

  // Handle notification action
  Future<void> handleNotificationAction(
    AppNotification notification,
    NotificationAction action,
  ) async {
    try {
      switch (action.action) {
        case 'mark_read':
          await markAsRead(notification.uid, notification.id);
          break;
        case 'navigate':
          // Handle navigation - this would be implemented in the UI layer
          break;
        case 'accept_friend_request':
          // Handle friend request acceptance
          break;
        case 'join_group':
          // Handle group joining
          break;
        default:
          debugPrint('Unknown action: ${action.action}');
      }
    } catch (e) {
      debugPrint('Error handling notification action: $e');
    }
  }

  // Private helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void _updateNotificationReadStatus(String notificationId, bool read) {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      final notification = _notifications[index];
      _notifications[index] = notification.copyWith(read: read);
      
      if (read && !notification.read) {
        _unreadCount = (_unreadCount - 1).clamp(0, _notifications.length);
      } else if (!read && notification.read) {
        _unreadCount++;
      }
      
      notifyListeners();
      _cacheData();
    }
  }

  void _startPeriodicRefresh(String uid) {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      refreshNotifications(uid);
    });
  }

  // Cache management
  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedNotifications = prefs.getString(_cacheKey);
      final cachedUnreadCount = prefs.getInt(_unreadCountKey) ?? 0;
      
      if (cachedNotifications != null) {
        final data = json.decode(cachedNotifications);
        _notifications = (data['notifications'] as List)
            .map((notif) => AppNotification.fromJson(notif))
            .toList();
        _unreadCount = cachedUnreadCount;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading cached notifications: $e');
    }
  }

  Future<void> _cacheData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'notifications': _notifications.map((n) => n.toJson()).toList(),
        'timestamp': DateTime.now().toIso8601String(),
      };
      await prefs.setString(_cacheKey, json.encode(data));
      await prefs.setInt(_unreadCountKey, _unreadCount);
    } catch (e) {
      debugPrint('Error caching notifications: $e');
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // Static helper methods
  static IconData getIconForNotificationType(String type) {
    switch (type) {
      case 'friend_request':
        return Icons.person_add;
      case 'friend_accepted':
        return Icons.people;
      case 'group_member_joined':
        return Icons.group_add;
      case 'group_joined':
        return Icons.group;
      case 'transaction_request':
        return Icons.swap_horiz;
      case 'transaction_completed':
        return Icons.check_circle;
      case 'achievement_unlocked':
        return Icons.emoji_events;
      case 'reward_earned':
        return Icons.star;
      case 'verification_approved':
        return Icons.verified;
      case 'system':
      default:
        return Icons.info;
    }
  }

  static Color getColorForNotificationType(String type) {
    switch (type) {
      case 'friend_request':
        return Colors.blue;
      case 'friend_accepted':
        return Colors.green;
      case 'group_member_joined':
      case 'group_joined':
        return Colors.purple;
      case 'transaction_request':
        return Colors.orange;
      case 'transaction_completed':
        return Colors.green;
      case 'achievement_unlocked':
        return Colors.amber;
      case 'reward_earned':
        return Colors.yellow;
      case 'verification_approved':
        return Colors.teal;
      case 'system':
      default:
        return Colors.grey;
    }
  }

  static Color getColorForPriority(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return Colors.grey;
      case NotificationPriority.normal:
        return Colors.blue;
      case NotificationPriority.high:
        return Colors.orange;
      case NotificationPriority.urgent:
        return Colors.red;
    }
  }
}