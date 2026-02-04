import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing user session and preferences
class SessionService {
  static const String _uidKey = 'uid';
  static const String _verificationStatusKey = 'verificationStatus';
  static const String _authTokenKey = 'auth_token';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  
  // Cache SharedPreferences instance for better performance
  static SharedPreferences? _prefs;
  
  // Store verification status for instant access
  static String _verificationStatus = 'unknown';
  
  /// Get verification status
  static String get verificationStatus => _verificationStatus;
  
  /// Set verification status with validation
  static set verificationStatus(String value) {
    const validStatuses = ['unknown', 'pending', 'verified', 'rejected'];
    if (validStatuses.contains(value)) {
      _verificationStatus = value;
      _saveVerificationStatus(value);
    }
  }
  
  /// Get or initialize SharedPreferences instance
  static Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }
  
  /// Save verification status to persistent storage
  static Future<void> _saveVerificationStatus(String status) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setString(_verificationStatusKey, status);
    } catch (_) {
      // Silently fail - not critical
    }
  }
  
  /// Load verification status from persistent storage
  static Future<void> loadVerificationStatus() async {
    try {
      final prefs = await _getPrefs();
      _verificationStatus = prefs.getString(_verificationStatusKey) ?? 'unknown';
    } catch (_) {
      _verificationStatus = 'unknown';
    }
  }

  /// Get current user's UID
  static Future<String?> getUid() async {
    try {
      final prefs = await _getPrefs();
      return prefs.getString(_uidKey);
    } catch (e) {
      return null;
    }
  }

  /// Alias for getUid for backward compatibility
  static Future<String?> getUserId() async {
    return getUid();
  }

  /// Set current user's UID
  static Future<bool> setUid(String uid) async {
    if (uid.isEmpty) return false;
    
    try {
      final prefs = await _getPrefs();
      return await prefs.setString(_uidKey, uid);
    } catch (e) {
      return false;
    }
  }

  /// Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final uid = await getUid();
    return uid != null && uid.isNotEmpty;
  }

  /// Clear all session data (logout)
  static Future<bool> clearSession() async {
    try {
      final prefs = await _getPrefs();
      _verificationStatus = 'unknown';
      await prefs.remove(_verificationStatusKey);
      await prefs.remove(_authTokenKey);
      await _secureStorage.delete(key: _authTokenKey);
      return await prefs.remove(_uidKey);
    } catch (e) {
      return false;
    }
  }
  
  /// Get authentication token
  static Future<String?> getToken() async {
    try {
      final storedToken = await _secureStorage.read(key: _authTokenKey);
      if (storedToken != null && storedToken.isNotEmpty) {
        return storedToken;
      }

      final prefs = await _getPrefs();
      final legacyToken = prefs.getString(_authTokenKey);
      if (legacyToken != null && legacyToken.isNotEmpty) {
        await _secureStorage.write(key: _authTokenKey, value: legacyToken);
        await prefs.remove(_authTokenKey);
      }
      return legacyToken;
    } catch (_) {
      return null;
    }
  }
  
  /// Set authentication token
  static Future<void> setToken(String token) async {
    try {
      if (token.isEmpty) return;
      await _secureStorage.write(key: _authTokenKey, value: token);
    } catch (_) {
      // Silently fail - not critical
    }
  }
  
  /// Reset cached instance (useful for testing)
  static void resetCache() {
    _prefs = null;
    _verificationStatus = 'unknown';
  }
}
