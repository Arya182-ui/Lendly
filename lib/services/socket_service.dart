import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/env_config.dart';
import 'firebase_auth_service.dart';
import 'app_logger.dart';

/// Socket.IO service with Firebase authentication
class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  final FirebaseAuthService _authService = FirebaseAuthService();
  IO.Socket? _socket;
  bool _isConnected = false;
  String? _currentUserId;

  /// Initialize socket connection with Firebase authentication
  Future<void> initialize() async {
    try {
      // Get Firebase ID token for authentication
      final token = await _authService.getIdToken();
      if (token == null) {
        logger.error('Cannot initialize socket: No authentication token', tag: 'SocketService');
        return;
      }

      final userId = await _authService.getStoredUserId();
      if (userId == null) {
        logger.error('Cannot initialize socket: No user ID', tag: 'SocketService');
        return;
      }

      _currentUserId = userId;

      // Create socket connection with authentication
      _socket = IO.io(
        EnvConfig.apiBaseUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .setAuth({
              'token': token, // Send Firebase ID token for authentication
            })
            .build()
      );

      // Set up event listeners
      _setupEventListeners();

      // Connect to socket
      _socket!.connect();

      logger.info('Socket initialized successfully', tag: 'SocketService', data: {
        'userId': userId,
        'serverUrl': EnvConfig.apiBaseUrl,
      });
    } catch (e) {
      logger.error('Failed to initialize socket', tag: 'SocketService', data: {
        'error': e.toString(),
      });
    }
  }

  /// Set up socket event listeners
  void _setupEventListeners() {
    _socket?.on('connect', (data) {
      _isConnected = true;
      logger.info('Socket connected successfully', tag: 'SocketService');
    });

    _socket?.on('authenticated', (data) {
      logger.info('Socket authenticated successfully', tag: 'SocketService', data: data);
    });

    _socket?.on('disconnect', (data) {
      _isConnected = false;
      logger.info('Socket disconnected', tag: 'SocketService', data: {'reason': data});
    });

    _socket?.on('connect_error', (error) {
      _isConnected = false;
      logger.error('Socket connection error', tag: 'SocketService', data: {
        'error': error.toString(),
      });
    });

    _socket?.on('error', (error) {
      logger.error('Socket error', tag: 'SocketService', data: {
        'error': error.toString(),
      });
    });
  }

  /// Join a chat room
  void joinRoom(String roomId) {
    if (_socket != null && _isConnected) {
      _socket!.emit('joinRoom', roomId);
      logger.info('Joined room', tag: 'SocketService', data: {'roomId': roomId});
    } else {
      logger.warning('Cannot join room: socket not connected', tag: 'SocketService');
    }
  }

  /// Send a message
  void sendMessage({
    required String roomId,
    required String to,
    required String message,
  }) {
    if (_socket != null && _isConnected && _currentUserId != null) {
      final messageData = {
        'roomId': roomId,
        'to': to,
        'message': message,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      _socket!.emit('sendMessage', messageData);
      
      logger.info('Message sent', tag: 'SocketService', data: {
        'roomId': roomId,
        'to': to,
        'messageLength': message.length,
      });
    } else {
      logger.warning('Cannot send message: socket not connected or user not authenticated', tag: 'SocketService');
    }
  }

  /// Listen for incoming messages
  void onMessage(Function(Map<String, dynamic>) callback) {
    _socket?.on('receiveMessage', (data) {
      logger.info('Message received', tag: 'SocketService', data: {
        'from': data['from'],
        'messageLength': data['message']?.length ?? 0,
      });
      callback(data);
    });
  }

  /// Remove message listener
  void offMessage() {
    _socket?.off('receiveMessage');
  }

  /// Check if socket is connected
  bool get isConnected => _isConnected;

  /// Get current user ID
  String? get currentUserId => _currentUserId;

  /// Refresh authentication token
  Future<void> refreshAuth() async {
    try {
      if (_socket == null) return;

      final token = await _authService.getIdToken(forceRefresh: true);
      if (token == null) {
        logger.error('Cannot refresh socket auth: No authentication token', tag: 'SocketService');
        return;
      }

      // Update socket authentication
      _socket!.auth = {'token': token};
      
      // Reconnect to apply new authentication
      if (_isConnected) {
        _socket!.disconnect();
        _socket!.connect();
      }

      logger.info('Socket authentication refreshed', tag: 'SocketService');
    } catch (e) {
      logger.error('Failed to refresh socket authentication', tag: 'SocketService', data: {
        'error': e.toString(),
      });
    }
  }

  /// Disconnect socket
  void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      _isConnected = false;
      _currentUserId = null;
      logger.info('Socket disconnected and disposed', tag: 'SocketService');
    }
  }

  /// Get socket instance for advanced operations
  IO.Socket? get socket => _socket;
}