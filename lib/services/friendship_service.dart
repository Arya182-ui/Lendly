import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:lendly/services/api_client.dart';
import '../config/env_config.dart';

/// Enhanced friendship service with real-time updates and better error handling
class FriendshipService extends ChangeNotifier {
  static String get baseUrl => EnvConfig.apiBaseUrl;
  static const Duration timeout = Duration(seconds: 15);

  // Cache for friendship status
  final Map<String, Map<String, dynamic>> _friendshipStatusCache = {};
  final Map<String, Timer> _cacheTimers = {};
  static const Duration cacheTimeout = Duration(minutes: 5);

  /// Friendship status types
  static const String STATUS_NONE = 'none';
  static const String STATUS_FRIENDS = 'friends';
  static const String STATUS_PENDING_SENT = 'pending_sent';
  static const String STATUS_PENDING_RECEIVED = 'pending_received';
  static const String STATUS_BLOCKED = 'blocked';
  static const String STATUS_SELF = 'self';

  /// Get cached friendship status or fetch new
  Future<Map<String, dynamic>> getFriendshipStatus(String uid1, String uid2) async {
    if (uid1.isEmpty || uid2.isEmpty) {
      throw ArgumentError('Both UIDs must be provided');
    }
    
    final cacheKey = _getCacheKey(uid1, uid2);
    
    // Return cached result if available and not expired
    if (_friendshipStatusCache.containsKey(cacheKey)) {
      return _friendshipStatusCache[cacheKey]!;
    }
    
    try {
      final data = await SimpleApiClient.get(
        '/user/friendship-status',
        queryParams: {'uid1': uid1, 'uid2': uid2},
        requiresAuth: true,
      );
      
      // Cache the result
      _cacheStatus(cacheKey, data);
      
      return data;
    } catch (e) {
      throw Exception('Failed to get friendship status: ${e.toString()}');
    }
  }

  /// Send friend request with optional message
  Future<Map<String, dynamic>> sendFriendRequest(String fromUid, String toUid, {String? message}) async {
    if (fromUid.isEmpty || toUid.isEmpty) {
      throw ArgumentError('Both UIDs must be provided');
    }
    
    if (fromUid == toUid) {
      throw ArgumentError('Cannot send friend request to yourself');
    }
    
    try {
      final response = await SimpleApiClient.post(
        '/user/send-friend-request',
        body: {
          'fromUid': fromUid,
          'toUid': toUid,
          if (message != null && message.trim().isNotEmpty) 'message': message.trim(),
        },
        requiresAuth: true,
      );
      
      // Invalidate cache for this relationship
      _invalidateCache(fromUid, toUid);
      notifyListeners();
      
      return response;
    } catch (e) {
      throw Exception('Failed to send friend request: ${e.toString()}');
    }
  }

  /// Accept friend request
  Future<Map<String, dynamic>> acceptFriendRequest(String fromUid, String toUid) async {
    if (fromUid.isEmpty || toUid.isEmpty) {
      throw ArgumentError('Both UIDs must be provided');
    }
    
    try {
      final response = await SimpleApiClient.post(
        '/user/accept-friend-request',
        body: {
          'fromUid': fromUid,
          'toUid': toUid,
        },
        requiresAuth: true,
      );
      
      // Invalidate cache for this relationship
      _invalidateCache(fromUid, toUid);
      notifyListeners();
      
      return response;
    } catch (e) {
      throw Exception('Failed to accept friend request: ${e.toString()}');
    }
  }

  /// Reject friend request
  Future<Map<String, dynamic>> rejectFriendRequest(String fromUid, String toUid) async {
    if (fromUid.isEmpty || toUid.isEmpty) {
      throw ArgumentError('Both UIDs must be provided');
    }
    
    try {
      final response = await SimpleApiClient.post(
        '/user/reject-friend-request',
        body: {
          'fromUid': fromUid,
          'toUid': toUid,
        },
        requiresAuth: true,
      );
      
      // Invalidate cache for this relationship
      _invalidateCache(fromUid, toUid);
      notifyListeners();
      
      return response;
    } catch (e) {
      throw Exception('Failed to reject friend request: ${e.toString()}');
    }
  }

  /// Remove friend
  Future<Map<String, dynamic>> removeFriend(String uid1, String uid2) async {
    if (uid1.isEmpty || uid2.isEmpty) {
      throw ArgumentError('Both UIDs must be provided');
    }
    
    try {
      final response = await SimpleApiClient.post(
        '/user/remove-friend',
        body: {
          'uid1': uid1,
          'uid2': uid2,
        },
        requiresAuth: true,
      );
      
      // Invalidate cache for this relationship
      _invalidateCache(uid1, uid2);
      notifyListeners();
      
      return response;
    } catch (e) {
      throw Exception('Failed to remove friend: ${e.toString()}');
    }
  }

  /// Block user
  Future<Map<String, dynamic>> blockUser(String blockerUid, String blockedUid) async {
    if (blockerUid.isEmpty || blockedUid.isEmpty) {
      throw ArgumentError('Both UIDs must be provided');
    }
    
    try {
      final response = await SimpleApiClient.post(
        '/user/block-user',
        body: {
          'blockerUid': blockerUid,
          'blockedUid': blockedUid,
        },
        requiresAuth: true,
      );
      
      // Invalidate cache for this relationship
      _invalidateCache(blockerUid, blockedUid);
      notifyListeners();
      
      return response;
    } catch (e) {
      throw Exception('Failed to block user: ${e.toString()}');
    }
  }

  /// Unblock user
  Future<Map<String, dynamic>> unblockUser(String blockerUid, String blockedUid) async {
    if (blockerUid.isEmpty || blockedUid.isEmpty) {
      throw ArgumentError('Both UIDs must be provided');
    }
    
    try {
      final response = await SimpleApiClient.post(
        '/user/unblock-user',
        body: {
          'blockerUid': blockerUid,
          'blockedUid': blockedUid,
        },
        requiresAuth: true,
      );
      
      // Invalidate cache for this relationship
      _invalidateCache(blockerUid, blockedUid);
      notifyListeners();
      
      return response;
    } catch (e) {
      throw Exception('Failed to unblock user: ${e.toString()}');
    }
  }

  /// Get friends list with enhanced data
  Future<Map<String, dynamic>> getFriendsAndRequests(String uid) async {
    if (uid.isEmpty) {
      throw ArgumentError('UID must be provided');
    }
    
    try {
      final data = await SimpleApiClient.get(
        '/user/friends',
        queryParams: {'uid': uid},
        requiresAuth: true,
      );
      
      notifyListeners();
      return data;
    } catch (e) {
      throw Exception('Failed to get friends: ${e.toString()}');
    }
  }

  /// Helper methods
  String _getCacheKey(String uid1, String uid2) {
    final uids = [uid1, uid2]..sort();
    return '${uids[0]}_${uids[1]}';
  }

  void _cacheStatus(String cacheKey, Map<String, dynamic> status) {
    _friendshipStatusCache[cacheKey] = status;
    
    // Set timer to clear cache
    _cacheTimers[cacheKey]?.cancel();
    _cacheTimers[cacheKey] = Timer(cacheTimeout, () {
      _friendshipStatusCache.remove(cacheKey);
      _cacheTimers.remove(cacheKey);
    });
  }

  void _invalidateCache(String uid1, String uid2) {
    final cacheKey = _getCacheKey(uid1, uid2);
    _friendshipStatusCache.remove(cacheKey);
    _cacheTimers[cacheKey]?.cancel();
    _cacheTimers.remove(cacheKey);
  }

  /// Clear all cache
  void clearCache() {
    _friendshipStatusCache.clear();
    for (final timer in _cacheTimers.values) {
      timer.cancel();
    }
    _cacheTimers.clear();
  }

  @override
  void dispose() {
    clearCache();
    super.dispose();
  }
}

/// Friendship status model for easier handling
class FriendshipStatus {
  final String status;
  final DateTime? since;
  final DateTime? sentAt;
  final String? message;
  final String? blockedBy;

  const FriendshipStatus({
    required this.status,
    this.since,
    this.sentAt,
    this.message,
    this.blockedBy,
  });

  factory FriendshipStatus.fromMap(Map<String, dynamic> map) {
    return FriendshipStatus(
      status: map['status'] ?? FriendshipService.STATUS_NONE,
      since: map['since'] != null 
        ? (map['since'] is String 
          ? DateTime.tryParse(map['since']) 
          : map['since'] is Map && map['since']['_seconds'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['since']['_seconds'] * 1000)
            : null)
        : null,
      sentAt: map['sentAt'] != null 
        ? (map['sentAt'] is String 
          ? DateTime.tryParse(map['sentAt']) 
          : map['sentAt'] is Map && map['sentAt']['_seconds'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['sentAt']['_seconds'] * 1000)
            : null)
        : null,
      message: map['message'],
      blockedBy: map['blockedBy'],
    );
  }

  bool get isFriends => status == FriendshipService.STATUS_FRIENDS;
  bool get isPendingSent => status == FriendshipService.STATUS_PENDING_SENT;
  bool get isPendingReceived => status == FriendshipService.STATUS_PENDING_RECEIVED;
  bool get isBlocked => status == FriendshipService.STATUS_BLOCKED;
  bool get isNone => status == FriendshipService.STATUS_NONE;
  bool get isSelf => status == FriendshipService.STATUS_SELF;

  @override
  String toString() {
    return 'FriendshipStatus(status: $status, since: $since, sentAt: $sentAt, message: $message, blockedBy: $blockedBy)';
  }
}