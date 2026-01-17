import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/env_config.dart';
import 'app_logger.dart';

/// Firebase Authentication Service
/// Handles user authentication, token management, and secure storage
class FirebaseAuthService {
  static final FirebaseAuthService _instance = FirebaseAuthService._internal();
  factory FirebaseAuthService() => _instance;
  FirebaseAuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Storage keys
  static const String _tokenKey = 'firebase_id_token';
  static const String _userIdKey = 'user_id';
  static const String _emailKey = 'user_email';
  static const String _refreshTokenKey = 'refresh_token';

  /// Current authenticated user
  User? get currentUser => _auth.currentUser;

  /// Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Initialize the service
  Future<void> initialize() async {
    try {
      // Listen to auth state changes
      _auth.authStateChanges().listen(_onAuthStateChanged);
      
      logger.info('FirebaseAuthService initialized', tag: 'Auth');
    } catch (e) {
      logger.error('Failed to initialize FirebaseAuthService', tag: 'Auth', data: {'error': e.toString()});
    }
  }

  /// Sign up with email and password
  Future<UserCredential?> signUp(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        await _storeUserData(credential.user!);
        logger.info('User signed up successfully', tag: 'Auth', data: {'uid': credential.user!.uid});
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      logger.warning('Sign up failed', tag: 'Auth', data: {
        'error_code': e.code,
        'error_message': e.message,
      });
      
      // Throw user-friendly error messages
      switch (e.code) {
        case 'email-already-in-use':
          throw Exception('email-already-in-use');
        case 'weak-password':
          throw Exception('weak-password');
        case 'invalid-email':
          throw Exception('invalid-email');
        case 'operation-not-allowed':
          throw Exception('operation-not-allowed');
        default:
          throw Exception(e.code);
      }
    } catch (e) {
      logger.error('Unexpected error during sign up', tag: 'Auth', data: {'error': e.toString()});
      throw Exception('network-request-failed');
    }
  }

  /// Sign in with email and password
  Future<UserCredential?> signIn(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        await _storeUserData(credential.user!);
        logger.info('User signed in successfully', tag: 'Auth', data: {'uid': credential.user!.uid});
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      logger.warning('Sign in failed', tag: 'Auth', data: {
        'error_code': e.code,
        'error_message': e.message,
      });
      
      // Throw user-friendly error messages
      switch (e.code) {
        case 'invalid-credential':
        case 'user-not-found':
        case 'wrong-password':
          throw Exception('invalid-credential');
        case 'invalid-email':
          throw Exception('invalid-email');
        case 'user-disabled':
          throw Exception('user-disabled');
        case 'too-many-requests':
          throw Exception('too-many-requests');
        default:
          throw Exception(e.code);
      }
    } catch (e) {
      logger.error('Unexpected error during sign in', tag: 'Auth', data: {'error': e.toString()});
      throw Exception('network-request-failed');
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _clearStoredData();
      logger.info('User signed out successfully', tag: 'Auth');
    } catch (e) {
      logger.error('Sign out failed', tag: 'Auth', data: {'error': e.toString()});
      rethrow;
    }
  }

  /// Get current Firebase ID token with enhanced token management
  /// Automatically refreshes if expired or if forceRefresh is true
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        logger.warning('No authenticated user for token request', tag: 'Auth');
        return null;
      }

      // Check if we should refresh proactively
      if (!forceRefresh) {
        final isFresh = await isTokenFresh();
        if (!isFresh) {
          logger.info('Token is stale, refreshing proactively', tag: 'Auth');
          forceRefresh = true;
        }
      }

      final token = await user.getIdToken(forceRefresh);
      
      // Store the fresh token
      await _secureStorage.write(key: _tokenKey, value: token);
      
      logger.info('Firebase ID token retrieved', tag: 'Auth', data: {
        'uid': user.uid,
        'force_refresh': forceRefresh,
        'token_length': token?.length ?? 0,
      });
      
      return token;
    } catch (e) {
      logger.error('Failed to get ID token', tag: 'Auth', data: {'error': e.toString()});
      return null;
    }
  }

  /// Get stored Firebase ID token
  Future<String?> getStoredIdToken() async {
    try {
      return await _secureStorage.read(key: _tokenKey);
    } catch (e) {
      logger.error('Failed to read stored token', tag: 'Auth', data: {'error': e.toString()});
      return null;
    }
  }

  /// Store ID token (used by API client after refresh)
  Future<void> storeIdToken(String token) async {
    try {
      await _secureStorage.write(key: _tokenKey, value: token);
      logger.info('ID token stored successfully', tag: 'Auth');
    } catch (e) {
      logger.error('Failed to store ID token', tag: 'Auth', data: {'error': e.toString()});
    }
  }

  /// Check if current token is fresh (less than 50 minutes old)
  /// Firebase tokens expire after 1 hour, so we refresh proactively
  Future<bool> isTokenFresh() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final tokenResult = await user.getIdTokenResult();
      final issuedAt = tokenResult.issuedAtTime;
      final now = DateTime.now();
      
      if (issuedAt == null) return false;
      
      // Consider token stale if it's older than 50 minutes
      const maxAge = Duration(minutes: 50);
      return now.difference(issuedAt) < maxAge;
    } catch (e) {
      logger.warning('Failed to check token freshness', tag: 'Auth', data: {'error': e.toString()});
      return false;
    }
  }

  /// Get stored user ID
  Future<String?> getStoredUserId() async {
    try {
      return await _secureStorage.read(key: _userIdKey);
    } catch (e) {
      logger.error('Failed to read stored user ID', tag: 'Auth', data: {'error': e.toString()});
      return null;
    }
  }

  /// Get stored user email
  Future<String?> getStoredUserEmail() async {
    try {
      return await _secureStorage.read(key: _emailKey);
    } catch (e) {
      logger.error('Failed to read stored user email', tag: 'Auth', data: {'error': e.toString()});
      return null;
    }
  }

  /// Check if user is authenticated
  bool get isAuthenticated => _auth.currentUser != null;

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      logger.info('Password reset email sent', tag: 'Auth', data: {'email': email});
    } on FirebaseAuthException catch (e) {
      logger.warning('Password reset failed', tag: 'Auth', data: {
        'error_code': e.code,
        'error_message': e.message,
      });
      
      // Throw user-friendly error messages
      switch (e.code) {
        case 'user-not-found':
          throw Exception('user-not-found');
        case 'invalid-email':
          throw Exception('invalid-email');
        case 'too-many-requests':
          throw Exception('too-many-requests');
        default:
          throw Exception(e.code);
      }
    } catch (e) {
      logger.error('Unexpected error sending password reset', tag: 'Auth', data: {'error': e.toString()});
      throw Exception('network-request-failed');
    }
  }

  /// Reload current user data
  Future<void> reloadUser() async {
    try {
      await _auth.currentUser?.reload();
      final user = _auth.currentUser;
      if (user != null) {
        await _storeUserData(user);
      }
    } catch (e) {
      logger.error('Failed to reload user data', tag: 'Auth', data: {'error': e.toString()});
    }
  }

  /// Delete current user account
  Future<void> deleteAccount() async {
    try {
      await _auth.currentUser?.delete();
      await _clearStoredData();
      logger.info('User account deleted', tag: 'Auth');
    } catch (e) {
      logger.error('Failed to delete account', tag: 'Auth', data: {'error': e.toString()});
      rethrow;
    }
  }

  /// Handle auth state changes
  void _onAuthStateChanged(User? user) async {
    if (user != null) {
      // User signed in
      await _storeUserData(user);
      logger.info('Auth state changed: signed in', tag: 'Auth', data: {'uid': user.uid});
    } else {
      // User signed out
      await _clearStoredData();
      logger.info('Auth state changed: signed out', tag: 'Auth');
    }
  }

  /// Store user data securely
  Future<void> _storeUserData(User user) async {
    try {
      final token = await user.getIdToken();
      
      await Future.wait([
        _secureStorage.write(key: _tokenKey, value: token),
        _secureStorage.write(key: _userIdKey, value: user.uid),
        _secureStorage.write(key: _emailKey, value: user.email ?? ''),
        if (user.refreshToken != null)
          _secureStorage.write(key: _refreshTokenKey, value: user.refreshToken!),
      ]);

      logger.info('User data stored securely', tag: 'Auth', data: {'uid': user.uid});
    } catch (e) {
      logger.error('Failed to store user data', tag: 'Auth', data: {'error': e.toString()});
    }
  }

  /// Clear all stored authentication data
  Future<void> _clearStoredData() async {
    try {
      await Future.wait([
        _secureStorage.delete(key: _tokenKey),
        _secureStorage.delete(key: _userIdKey),
        _secureStorage.delete(key: _emailKey),
        _secureStorage.delete(key: _refreshTokenKey),
      ]);

      logger.info('Stored auth data cleared', tag: 'Auth');
    } catch (e) {
      logger.error('Failed to clear stored data', tag: 'Auth', data: {'error': e.toString()});
    }
  }

  /// Get user authentication status with detailed info
  Future<Map<String, dynamic>> getAuthStatus() async {
    final user = _auth.currentUser;
    if (user == null) {
      return {
        'authenticated': false,
        'user': null,
      };
    }

    return {
      'authenticated': true,
      'user': {
        'uid': user.uid,
        'email': user.email,
        'emailVerified': user.emailVerified,
        'displayName': user.displayName,
        'photoURL': user.photoURL,
        'creationTime': user.metadata.creationTime?.toIso8601String(),
        'lastSignInTime': user.metadata.lastSignInTime?.toIso8601String(),
      },
      'hasStoredToken': await getStoredIdToken() != null,
    };
  }
}