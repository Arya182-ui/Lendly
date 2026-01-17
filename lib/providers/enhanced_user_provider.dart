/// Enhanced User Provider with Security-Aware State Management
/// Integrates with the backend security enhancements
import 'package:flutter/foundation.dart';
import '../services/firebase_auth_service.dart';
import '../services/api_client.dart';
import '../utils/enhanced_error_handling.dart';
import '../services/app_logger.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Enhanced User State Model
class UserState {
  final User? firebaseUser;
  final Map<String, dynamic>? userData;
  final bool isAuthenticated;
  final bool isTokenFresh;
  final bool hasNetworkConnection;
  final DateTime? lastTokenRefresh;
  final List<ApiError> recentErrors;
  final bool isLoading;
  final String? lastError;

  const UserState({
    this.firebaseUser,
    this.userData,
    this.isAuthenticated = false,
    this.isTokenFresh = true,
    this.hasNetworkConnection = true,
    this.lastTokenRefresh,
    this.recentErrors = const [],
    this.isLoading = false,
    this.lastError,
  });

  UserState copyWith({
    User? firebaseUser,
    Map<String, dynamic>? userData,
    bool? isAuthenticated,
    bool? isTokenFresh,
    bool? hasNetworkConnection,
    DateTime? lastTokenRefresh,
    List<ApiError>? recentErrors,
    bool? isLoading,
    String? lastError,
  }) {
    return UserState(
      firebaseUser: firebaseUser ?? this.firebaseUser,
      userData: userData ?? this.userData,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isTokenFresh: isTokenFresh ?? this.isTokenFresh,
      hasNetworkConnection: hasNetworkConnection ?? this.hasNetworkConnection,
      lastTokenRefresh: lastTokenRefresh ?? this.lastTokenRefresh,
      recentErrors: recentErrors ?? this.recentErrors,
      isLoading: isLoading ?? this.isLoading,
      lastError: lastError ?? this.lastError,
    );
  }

  /// Get user's display name or fallback
  String get displayName {
    if (userData?['name'] != null) return userData!['name'];
    if (firebaseUser?.displayName != null) return firebaseUser!.displayName!;
    if (firebaseUser?.email != null) return firebaseUser!.email!.split('@')[0];
    return 'User';
  }

  /// Get user's email
  String? get email => userData?['email'] ?? firebaseUser?.email;

  /// Get user's verification status
  String get verificationStatus => userData?['verificationStatus'] ?? 'pending';

  /// Check if user is verified
  bool get isVerified => verificationStatus == 'verified';

  /// Get trust score
  double get trustScore => (userData?['trustScore'] as num?)?.toDouble() ?? 0.0;

  /// Get trust tier
  String get trustTier {
    if (trustScore >= 80) return 'Gold';
    if (trustScore >= 60) return 'Silver';
    return 'Bronze';
  }

  /// Get user's college
  String? get college => userData?['college'];

  /// Get Lendly coins balance
  int get coinsBalance => userData?['coinsBalance'] ?? 0;

  /// Check if there are critical errors requiring attention
  bool get hasCriticalErrors {
    return recentErrors.any((error) => 
      error.requiresReauth || 
      error.code == ApiErrorCodes.authTokenRevoked
    );\n  }

  /// Get the most recent critical error
  ApiError? get mostRecentCriticalError {
    try {
      return recentErrors.lastWhere((error) => 
        error.requiresReauth || error.requiresTokenRefresh
      );
    } catch (_) {
      return null;
    }
  }

  @override
  String toString() {
    return 'UserState(isAuthenticated: $isAuthenticated, isTokenFresh: $isTokenFresh, displayName: $displayName)';
  }
}

/// Enhanced User Provider with Security Features
class EnhancedUserProvider with ChangeNotifier {
  final FirebaseAuthService _authService = FirebaseAuthService();
  final ApiClient _apiClient = ApiClient();
  
  UserState _state = const UserState();
  UserState get state => _state;

  // Legacy getters for backward compatibility
  User? get user => _state.firebaseUser;
  Map<String, dynamic>? get userData => _state.userData;
  bool get isAuthenticated => _state.isAuthenticated;
  bool get isLoading => _state.isLoading;
  String? get lastError => _state.lastError;

  /// Initialize the provider
  Future<void> initialize() async {
    logger.info('Initializing EnhancedUserProvider', tag: 'UserProvider');
    
    // Listen to auth state changes
    _authService.authStateChanges.listen(_handleAuthStateChange);
    
    // Check initial auth state
    await _handleAuthStateChange(_authService.currentUser);
    
    // Start periodic token freshness checks
    _startTokenFreshnessMonitoring();
  }

  /// Handle Firebase auth state changes
  Future<void> _handleAuthStateChange(User? user) async {
    logger.info('Auth state changed', tag: 'UserProvider', data: {
      'hasUser': user != null,
      'uid': user?.uid,
    });

    _updateState(_state.copyWith(
      firebaseUser: user,
      isAuthenticated: user != null,
      isLoading: user != null, // Load user data if authenticated
    ));

    if (user != null) {
      await _loadUserData();
      await _checkTokenFreshness();
    } else {
      _updateState(_state.copyWith(
        userData: null,
        isLoading: false,
        isTokenFresh: true,
        recentErrors: [],
      ));
    }
  }

  /// Load user data from API with enhanced error handling
  Future<void> _loadUserData() async {
    try {
      logger.info('Loading user data', tag: 'UserProvider');
      
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/user/profile',
        cacheDuration: const Duration(minutes: 5),
      );

      if (response.isSuccess && response.data != null) {
        _updateState(_state.copyWith(
          userData: response.data,
          isLoading: false,
          lastError: null,
        ));
        logger.info('User data loaded successfully', tag: 'UserProvider');
      } else {
        await _handleApiError(response);
      }
    } catch (e) {
      logger.error('Failed to load user data', tag: 'UserProvider', data: {'error': e.toString()});
      _updateState(_state.copyWith(
        isLoading: false,
        lastError: 'Failed to load user profile',
      ));
    }
  }

  /// Handle API errors with enhanced security error handling
  Future<void> _handleApiError(ApiResponse response) async {
    final apiError = response.apiError;
    
    if (apiError != null) {
      // Add to recent errors list (keep last 10)
      final updatedErrors = [..._state.recentErrors, apiError];
      if (updatedErrors.length > 10) {
        updatedErrors.removeAt(0);
      }

      _updateState(_state.copyWith(
        recentErrors: updatedErrors,
        isLoading: false,
        lastError: response.userFriendlyError,
        isTokenFresh: !apiError.requiresTokenRefresh,
      ));

      // Handle different error types
      final action = await ErrorHandler.handleApiError(
        apiError,
        onTokenRefresh: _refreshToken,
        onReauthRequired: _handleReauthRequired,
      );

      switch (action) {
        case ErrorAction.retryAfterTokenRefresh:
          // Token refresh was initiated, retry loading user data
          await Future.delayed(const Duration(seconds: 2));
          await _loadUserData();
          break;
        case ErrorAction.requiresReauth:
          await _handleReauthRequired();
          break;
        case ErrorAction.retry:
          // Retry with exponential backoff
          await Future.delayed(const Duration(seconds: 2));
          await _loadUserData();
          break;
        case ErrorAction.showError:
          // Error is already set in state, UI will show it
          break;
      }
    } else {
      _updateState(_state.copyWith(
        isLoading: false,
        lastError: response.error ?? 'Unknown error',
      ));
    }
  }

  /// Refresh authentication token
  Future<void> _refreshToken() async {
    logger.info('Refreshing authentication token', tag: 'UserProvider');
    
    try {
      final token = await _authService.getIdToken(forceRefresh: true);
      
      if (token != null) {
        _updateState(_state.copyWith(
          isTokenFresh: true,
          lastTokenRefresh: DateTime.now(),
        ));
        logger.info('Token refreshed successfully', tag: 'UserProvider');
      } else {
        logger.warning('Token refresh failed - no token returned', tag: 'UserProvider');
        await _handleReauthRequired();
      }
    } catch (e) {
      logger.error('Token refresh failed', tag: 'UserProvider', data: {'error': e.toString()});
      await _handleReauthRequired();
    }
  }

  /// Handle re-authentication requirement
  Future<void> _handleReauthRequired() async {
    logger.warning('Re-authentication required', tag: 'UserProvider');
    
    await signOut();
    
    // Notify UI to show login screen
    // This could be handled through navigation service or app state
  }

  /// Check token freshness periodically
  void _startTokenFreshnessMonitoring() {
    // Check token freshness every 30 minutes
    Stream.periodic(const Duration(minutes: 30)).listen((_) async {
      if (_state.isAuthenticated) {
        await _checkTokenFreshness();
      }
    });
  }

  /// Check if token is fresh and refresh if needed
  Future<void> _checkTokenFreshness() async {
    try {
      final isTokenFresh = await _authService.isTokenFresh();
      
      _updateState(_state.copyWith(isTokenFresh: isTokenFresh));
      
      if (!isTokenFresh && _state.isAuthenticated) {
        logger.info('Token is stale, refreshing proactively', tag: 'UserProvider');
        await _refreshToken();
      }
    } catch (e) {
      logger.warning('Failed to check token freshness', tag: 'UserProvider', data: {'error': e.toString()});
    }
  }

  /// Sign out with cleanup
  Future<void> signOut() async {
    try {
      logger.info('Signing out user', tag: 'UserProvider');
      
      _updateState(_state.copyWith(isLoading: true));
      
      await _authService.signOut();
      await _apiClient.clearCache();
      
      _updateState(const UserState()); // Reset to initial state
      
      logger.info('User signed out successfully', tag: 'UserProvider');
    } catch (e) {
      logger.error('Sign out failed', tag: 'UserProvider', data: {'error': e.toString()});
      _updateState(_state.copyWith(
        isLoading: false,
        lastError: 'Failed to sign out',
      ));
    }
  }

  /// Refresh user data manually
  Future<void> refreshUserData() async {
    if (!_state.isAuthenticated) return;
    
    _updateState(_state.copyWith(isLoading: true));
    await _loadUserData();
  }

  /// Clear recent errors
  void clearRecentErrors() {
    _updateState(_state.copyWith(recentErrors: []));
  }

  /// Clear last error
  void clearLastError() {
    _updateState(_state.copyWith(lastError: null));
  }

  /// Update user data locally (for optimistic updates)
  void updateUserDataLocally(Map<String, dynamic> updates) {
    final currentData = _state.userData ?? <String, dynamic>{};
    final updatedData = {...currentData, ...updates};
    
    _updateState(_state.copyWith(userData: updatedData));
  }

  /// Update state and notify listeners
  void _updateState(UserState newState) {
    _state = newState;
    notifyListeners();
  }

  /// Get formatted trust score display
  String getFormattedTrustScore() {
    return '${_state.trustScore.toInt()}/100 (${_state.trustTier})';
  }

  /// Get formatted coins balance
  String getFormattedCoinsBalance() {
    final balance = _state.coinsBalance;
    if (balance >= 1000) {
      return '${(balance / 1000).toStringAsFixed(1)}k';
    }
    return balance.toString();
  }

  @override
  void dispose() {
    // Clean up any resources
    super.dispose();
  }
}