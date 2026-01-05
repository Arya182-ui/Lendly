import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/env_config.dart';
import 'session_service.dart';
import 'firebase_auth_service.dart';

/// Enhanced chat service with advanced features
class ChatService extends ChangeNotifier {
  static String get baseUrl => EnvConfig.apiBaseUrl;
  static const Duration timeout = Duration(seconds: 15);

  final FirebaseAuthService _authService = FirebaseAuthService();

  // Chat state management
  final Map<String, List<Map<String, dynamic>>> _messagesCache = {};
  final Map<String, Set<String>> _typingUsers = {};
  final Map<String, Timer> _typingTimers = {};
  
  /// Message status types
  static const String STATUS_SENDING = 'sending';
  static const String STATUS_SENT = 'sent';
  static const String STATUS_DELIVERED = 'delivered';
  static const String STATUS_READ = 'read';
  static const String STATUS_FAILED = 'failed';

  /// Get messages for a chat with caching
  Future<List<Map<String, dynamic>>> getMessages(String chatId, {
    int limit = 50,
    String? before,
  }) async {
    if (chatId.isEmpty) {
      throw ArgumentError('Chat ID cannot be empty');
    }
    
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        if (before != null) 'before': before,
      };
      
      final token = await _authService.getIdToken();
      final url = Uri.parse('$baseUrl/chat/messages/$chatId')
          .replace(queryParameters: queryParams);
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      ).timeout(timeout);
      
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
      
      final data = json.decode(response.body);
      
      if (data is Map && data['messages'] is List) {
        final messages = List<Map<String, dynamic>>.from(data['messages']);
        _messagesCache[chatId] = messages;
        notifyListeners();
        return messages;
      }
      
      throw Exception('Invalid response format');
    } catch (e) {
      throw Exception('Failed to load messages: ${e.toString()}');
    }
  }

  /// Send a message via REST API (fallback for Socket.IO)
  Future<Map<String, dynamic>> sendMessage({
    required String chatId,
    required String senderId,
    required String text,
    String type = 'text',
    String? imageUrl,
    String? fileUrl,
    String? fileName,
  }) async {
    if (chatId.isEmpty || senderId.isEmpty || text.trim().isEmpty) {
      throw ArgumentError('Required fields cannot be empty');
    }
    
    if (text.length > 2000) {
      throw ArgumentError('Message too long (max 2000 characters)');
    }
    
    try {
      final body = {
        'chatId': chatId,
        'senderId': senderId,
        'text': text.trim(),
        'type': type,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (fileUrl != null) 'fileUrl': fileUrl,
        if (fileName != null) 'fileName': fileName,
      };
      
      final token = await _authService.getIdToken();
      final url = Uri.parse('$baseUrl/chat/send');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: json.encode(body),
      ).timeout(timeout);
      
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
      
      final data = json.decode(response.body);
      
      // Update local cache
      if (_messagesCache.containsKey(chatId)) {
        final newMessage = {
          'id': data['messageId'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
          'senderId': senderId,
          'text': text,
          'type': type,
          'createdAt': DateTime.now().toIso8601String(),
          'status': STATUS_SENT,
          if (imageUrl != null) 'imageUrl': imageUrl,
          if (fileUrl != null) 'fileUrl': fileUrl,
          if (fileName != null) 'fileName': fileName,
        };
        _messagesCache[chatId]!.add(newMessage);
        notifyListeners();
      }
      
      return data;
    } catch (e) {
      throw Exception('Failed to send message: ${e.toString()}');
    }
  }

  /// Delete a message
  Future<void> deleteMessage({
    required String chatId,
    required String messageId,
    required String userId,
  }) async {
    if (chatId.isEmpty || messageId.isEmpty || userId.isEmpty) {
      throw ArgumentError('Required fields cannot be empty');
    }
    
    try {
      final token = await _authService.getIdToken();
      final url = Uri.parse('$baseUrl/chat/message/$messageId');
      
      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'chatId': chatId,
          'userId': userId,
        }),
      ).timeout(timeout);
      
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
      
      // Update local cache
      if (_messagesCache.containsKey(chatId)) {
        final messages = _messagesCache[chatId]!;
        final messageIndex = messages.indexWhere((msg) => msg['id'] == messageId);
        if (messageIndex != -1) {
          messages[messageIndex] = {
            ...messages[messageIndex],
            'deleted': true,
            'text': '[Message deleted]',
          };
          notifyListeners();
        }
      }
    } catch (e) {
      throw Exception('Failed to delete message: ${e.toString()}');
    }
  }

  /// Edit a message
  Future<void> editMessage({
    required String chatId,
    required String messageId,
    required String userId,
    required String newText,
  }) async {
    if (chatId.isEmpty || messageId.isEmpty || userId.isEmpty || newText.trim().isEmpty) {
      throw ArgumentError('Required fields cannot be empty');
    }
    
    if (newText.length > 2000) {
      throw ArgumentError('Message too long (max 2000 characters)');
    }
    
    try {
      final token = await _authService.getIdToken();
      final url = Uri.parse('$baseUrl/chat/message/$messageId');
      
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'chatId': chatId,
          'userId': userId,
          'newText': newText.trim(),
        }),
      ).timeout(timeout);
      
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
      
      // Update local cache
      if (_messagesCache.containsKey(chatId)) {
        final messages = _messagesCache[chatId]!;
        final messageIndex = messages.indexWhere((msg) => msg['id'] == messageId);
        if (messageIndex != -1) {
          messages[messageIndex] = {
            ...messages[messageIndex],
            'text': newText,
            'edited': true,
            'editedAt': DateTime.now().toIso8601String(),
          };
          notifyListeners();
        }
      }
    } catch (e) {
      throw Exception('Failed to edit message: ${e.toString()}');
    }
  }

  /// Add reaction to message
  Future<void> addReaction({
    required String chatId,
    required String messageId,
    required String userId,
    required String reaction,
  }) async {
    if (chatId.isEmpty || messageId.isEmpty || userId.isEmpty || reaction.isEmpty) {
      throw ArgumentError('Required fields cannot be empty');
    }
    
    try {
      final token = await _authService.getIdToken();
      final url = Uri.parse('$baseUrl/chat/reaction');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'chatId': chatId,
          'messageId': messageId,
          'userId': userId,
          'reaction': reaction,
        }),
      ).timeout(timeout);
      
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
      
      final data = json.decode(response.body);
      
      // Update local cache
      if (_messagesCache.containsKey(chatId)) {
        final messages = _messagesCache[chatId]!;
        final messageIndex = messages.indexWhere((msg) => msg['id'] == messageId);
        if (messageIndex != -1) {
          messages[messageIndex] = {
            ...messages[messageIndex],
            'reactions': data['reactions'] ?? {},
          };
          notifyListeners();
        }
      }
    } catch (e) {
      throw Exception('Failed to add reaction: ${e.toString()}');
    }
  }

  /// Mark messages as read
  Future<void> markMessagesRead(String chatId, String userId) async {
    if (chatId.isEmpty || userId.isEmpty) {
      throw ArgumentError('Required fields cannot be empty');
    }
    
    try {
      final token = await _authService.getIdToken();
      final url = Uri.parse('$baseUrl/chat/mark-read');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'chatId': chatId,
          'userId': userId,
        }),
      ).timeout(timeout);
      
      if (response.statusCode != 200) {
        debugPrint('Failed to mark as read: HTTP ${response.statusCode}');
      }
    } catch (e) {
      // Don't throw error for read status - it's not critical
      debugPrint('Failed to mark messages as read: ${e.toString()}');
    }
  }

  /// Get or create a chat
  Future<Map<String, dynamic>> getOrCreateChat(String uid1, String uid2) async {
    if (uid1.isEmpty || uid2.isEmpty) {
      throw ArgumentError('Both UIDs must be provided');
    }
    
    if (uid1 == uid2) {
      throw ArgumentError('Cannot create chat with yourself');
    }
    
    try {
      final token = await _authService.getIdToken();
      final url = Uri.parse('$baseUrl/chat/get-or-create-chat');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'uid1': uid1,
          'uid2': uid2,
        }),
      ).timeout(timeout);
      
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
      
      final data = json.decode(response.body);
      return data;
    } catch (e) {
      throw Exception('Failed to create chat: ${e.toString()}');
    }
  }

  /// Get user's chat list
  Future<List<Map<String, dynamic>>> getChatList(String uid, {int limit = 20}) async {
    if (uid.isEmpty) {
      throw ArgumentError('UID cannot be empty');
    }
    
    try {
      final token = await _authService.getIdToken();
      final url = Uri.parse('$baseUrl/chat/list/$uid')
          .replace(queryParameters: {'limit': limit.toString()});
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      ).timeout(timeout);
      
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
      
      final data = json.decode(response.body);
      
      if (data is List) {
        return data.cast<Map<String, dynamic>>();
      }
      
      throw Exception('Invalid response format');
    } catch (e) {
      throw Exception('Failed to load chats: ${e.toString()}');
    }
  }

  // Typing indicators management
  void setUserTyping(String chatId, String userId, bool isTyping) {
    if (!_typingUsers.containsKey(chatId)) {
      _typingUsers[chatId] = <String>{};
    }
    
    if (isTyping) {
      _typingUsers[chatId]!.add(userId);
      
      // Auto-remove typing status after 3 seconds
      _typingTimers[chatId]?.cancel();
      _typingTimers[chatId] = Timer(const Duration(seconds: 3), () {
        _typingUsers[chatId]?.remove(userId);
        notifyListeners();
      });
    } else {
      _typingUsers[chatId]?.remove(userId);
      _typingTimers[chatId]?.cancel();
    }
    
    notifyListeners();
  }

  Set<String> getTypingUsers(String chatId) {
    return _typingUsers[chatId] ?? <String>{};
  }

  // Message status updates
  void updateMessageStatus(String chatId, String messageId, String status) {
    if (_messagesCache.containsKey(chatId)) {
      final messages = _messagesCache[chatId]!;
      final messageIndex = messages.indexWhere((msg) => msg['id'] == messageId);
      if (messageIndex != -1) {
        messages[messageIndex] = {
          ...messages[messageIndex],
          'status': status,
        };
        notifyListeners();
      }
    }
  }

  // Add message to local cache (for real-time updates)
  void addMessageToCache(String chatId, Map<String, dynamic> message) {
    if (!_messagesCache.containsKey(chatId)) {
      _messagesCache[chatId] = [];
    }
    
    // Check if message already exists (avoid duplicates)
    final existingIndex = _messagesCache[chatId]!.indexWhere(
      (msg) => msg['id'] == message['id'] || 
               (msg['timestamp'] == message['timestamp'] && 
                msg['senderId'] == message['senderId'])
    );
    
    if (existingIndex == -1) {
      _messagesCache[chatId]!.add(message);
      notifyListeners();
    }
  }

  // Clear cache
  void clearCache() {
    _messagesCache.clear();
    _typingUsers.clear();
    for (final timer in _typingTimers.values) {
      timer.cancel();
    }
    _typingTimers.clear();
    notifyListeners();
  }

  // Get cached messages
  List<Map<String, dynamic>>? getCachedMessages(String chatId) {
    return _messagesCache[chatId];
  }

  @override
  void dispose() {
    for (final timer in _typingTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }
}

/// Message model for type safety
class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final String type;
  final DateTime createdAt;
  final String status;
  final bool deleted;
  final bool edited;
  final DateTime? editedAt;
  final String? imageUrl;
  final String? fileUrl;
  final String? fileName;
  final Map<String, List<String>>? reactions;
  final List<String>? readBy;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.type,
    required this.createdAt,
    required this.status,
    this.deleted = false,
    this.edited = false,
    this.editedAt,
    this.imageUrl,
    this.fileUrl,
    this.fileName,
    this.reactions,
    this.readBy,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id']?.toString() ?? '',
      senderId: map['senderId']?.toString() ?? '',
      text: map['text']?.toString() ?? '',
      type: map['type']?.toString() ?? 'text',
      createdAt: _parseDateTime(map['createdAt']) ?? DateTime.now(),
      status: map['status']?.toString() ?? ChatService.STATUS_SENT,
      deleted: map['deleted'] ?? false,
      edited: map['edited'] ?? false,
      editedAt: _parseDateTime(map['editedAt']),
      imageUrl: map['imageUrl']?.toString(),
      fileUrl: map['fileUrl']?.toString(),
      fileName: map['fileName']?.toString(),
      reactions: map['reactions'] != null 
        ? Map<String, List<String>>.from(
            (map['reactions'] as Map).map(
              (key, value) => MapEntry(
                key.toString(), 
                List<String>.from(value ?? [])
              )
            )
          )
        : null,
      readBy: map['readBy'] != null 
        ? List<String>.from(map['readBy']) 
        : null,
    );
  }

  static DateTime? _parseDateTime(dynamic dateTime) {
    if (dateTime == null) return null;
    
    try {
      // If it's already a DateTime object
      if (dateTime is DateTime) {
        return dateTime;
      }
      
      // If it's a String (ISO format)
      if (dateTime is String) {
        return DateTime.tryParse(dateTime);
      }
      
      // If it's a number (milliseconds since epoch)
      if (dateTime is int) {
        return DateTime.fromMillisecondsSinceEpoch(dateTime);
      }
      
      // If it's a Firestore Timestamp object with _seconds
      if (dateTime is Map) {
        if (dateTime['_seconds'] != null) {
          return DateTime.fromMillisecondsSinceEpoch(
            (dateTime['_seconds'] as int) * 1000
          );
        }
        // Sometimes Firestore sends 'seconds' instead of '_seconds'
        if (dateTime['seconds'] != null) {
          return DateTime.fromMillisecondsSinceEpoch(
            (dateTime['seconds'] as int) * 1000
          );
        }
      }
    } catch (e) {
      print('Error parsing DateTime: $e, value: $dateTime');
    }
    
    // Fallback to current time
    return DateTime.now();
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'text': text,
      'type': type,
      'createdAt': createdAt.toIso8601String(),
      'status': status,
      'deleted': deleted,
      'edited': edited,
      if (editedAt != null) 'editedAt': editedAt!.toIso8601String(),
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (fileUrl != null) 'fileUrl': fileUrl,
      if (fileName != null) 'fileName': fileName,
      if (reactions != null) 'reactions': reactions,
      if (readBy != null) 'readBy': readBy,
    };
  }

  bool get isImage => type == 'image' && imageUrl != null;
  bool get isFile => type == 'file' && fileUrl != null;
  bool get hasReactions => reactions?.isNotEmpty == true;
  
  @override
  String toString() {
    return 'ChatMessage(id: $id, senderId: $senderId, text: $text, type: $type, status: $status)';
  }
}
