/// Enhanced Network and Connectivity Manager
/// Provides intelligent network monitoring and automatic retry mechanisms
import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
class NetworkManager {
  static final NetworkManager _instance = NetworkManager._internal();
  factory NetworkManager() => _instance;
  NetworkManager._internal();
  final Connectivity _connectivity = Connectivity();
  final StreamController<NetworkStatus> _networkController =
      StreamController<NetworkStatus>.broadcast();
  NetworkStatus _currentStatus = NetworkStatus.unknown;
  Timer? _healthCheckTimer;
  bool _isInitialized = false;
  /// Get network status stream
  Stream<NetworkStatus> get networkStream => _networkController.stream;
  
  /// Get current network status
  NetworkStatus get currentStatus => _currentStatus;
  
  /// Check if network is available
  bool get isConnected => _currentStatus == NetworkStatus.connected;
  /// Initialize network monitoring
  Future<void> initialize() async {
    if (_isInitialized) return;
    // Listen to connectivity changes
    _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
    
    // Check initial status
    await _checkNetworkStatus();
    
    // Start periodic health checks
    _startHealthCheck();
    
    _isInitialized = true;
  }
  /// Dispose resources
  void dispose() {
    _healthCheckTimer?.cancel();
    _networkController.close();
  }
  /// Check network connectivity and server reachability
  Future<NetworkStatus> _checkNetworkStatus() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      
      if (connectivityResult == ConnectivityResult.none) {
        _updateNetworkStatus(NetworkStatus.disconnected);
        return _currentStatus;
      }
      // Test actual internet connectivity with our backend
      final isServerReachable = await _testServerConnectivity();
      
      if (isServerReachable) {
        _updateNetworkStatus(NetworkStatus.connected);
      } else {
        _updateNetworkStatus(NetworkStatus.limitedConnectivity);
      }
      
      return _currentStatus;
    } catch (e) {
      _updateNetworkStatus(NetworkStatus.error);
      return _currentStatus;
    }
  }
  /// Test if our backend server is reachable
  Future<bool> _testServerConnectivity() async {
    try {
      final response = await http
          .get(
            Uri.parse('https://lendly-backend-production.up.railway.app/health'),
          )
          .timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  /// Handle connectivity changes
  void _onConnectivityChanged(ConnectivityResult result) {
    _checkNetworkStatus();
  }
  /// Update network status and notify listeners
  void _updateNetworkStatus(NetworkStatus status) {
    if (_currentStatus != status) {
      _currentStatus = status;
      _networkController.add(status);
    }
  }
  /// Start periodic health checks
  void _startHealthCheck() {
    _healthCheckTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => _checkNetworkStatus(),
    );
  }
  /// Force network status check
  Future<NetworkStatus> checkNetworkStatus() => _checkNetworkStatus();
}
/// Network status enumeration
enum NetworkStatus {
  connected,
  disconnected,
  limitedConnectivity,
  error,
  unknown,
}
/// Retry Manager for Failed Requests
class RetryManager {
  static const int defaultMaxRetries = 3;
  static const Duration defaultBaseDelay = Duration(seconds: 1);
  /// Execute a function with automatic retry logic
  static Future<T> executeWithRetry<T>(
    Future<T> Function() operation, {
    int maxRetries = defaultMaxRetries,
    Duration baseDelay = defaultBaseDelay,
    bool Function(dynamic error)? shouldRetry,
    Duration Function(int attempt)? delayCalculator,
    void Function(int attempt, dynamic error)? onRetry,
  }) async {
    int attempt = 0;
    dynamic lastError;
    while (attempt <= maxRetries) {
      try {
        return await operation();
      } catch (error) {
        lastError = error;
        attempt++;
        // Check if we should retry this error
        if (attempt > maxRetries || (shouldRetry != null && !shouldRetry(error))) {
          rethrow;
        }
        // Calculate delay for next attempt
        final delay = delayCalculator?.call(attempt) ?? 
            _calculateExponentialBackoff(attempt, baseDelay);
        // Notify about retry
        onRetry?.call(attempt, error);
        // Wait before retry
        await Future.delayed(delay);
      }
    }
    throw lastError;
  }
  /// Calculate exponential backoff delay
  static Duration _calculateExponentialBackoff(int attempt, Duration baseDelay) {
    final multiplier = (1 << (attempt - 1)); // 2^(attempt-1)
    final delayMs = baseDelay.inMilliseconds * multiplier;
    return Duration(milliseconds: delayMs.clamp(0, 30000)); // Max 30 seconds
  }
  /// Check if error is retryable
  static bool isRetryableError(dynamic error) {
    if (error is SocketException) return true;
    if (error is TimeoutException) return true;
    if (error is HttpException) {
      // Retry on server errors but not client errors
      return error.toString().contains('500') ||
             error.toString().contains('502') ||
             error.toString().contains('503') ||
             error.toString().contains('504');
    }
    return false;
  }
}
/// Connection Quality Monitor
class ConnectionQualityMonitor {
  static final ConnectionQualityMonitor _instance = ConnectionQualityMonitor._internal();
  factory ConnectionQualityMonitor() => _instance;
  ConnectionQualityMonitor._internal();
  final List<int> _latencyHistory = [];
  final int _maxHistoryLength = 10;
  ConnectionQuality _currentQuality = ConnectionQuality.unknown;
  /// Get current connection quality
  ConnectionQuality get currentQuality => _currentQuality;
  /// Test connection quality by measuring latency
  Future<ConnectionQuality> testQuality() async {
    try {
      final stopwatch = Stopwatch()..start();
      
      final response = await http
          .head(Uri.parse('https://lendly-backend-production.up.railway.app/health'))
          .timeout(const Duration(seconds: 5));
      
      stopwatch.stop();
      
      if (response.statusCode == 200) {
        final latency = stopwatch.elapsedMilliseconds;
        _updateLatencyHistory(latency);
        _currentQuality = _calculateQuality();
      } else {
        _currentQuality = ConnectionQuality.poor;
      }
    } catch (e) {
      _currentQuality = ConnectionQuality.poor;
    }
    return _currentQuality;
  }
  /// Update latency history
  void _updateLatencyHistory(int latency) {
    _latencyHistory.add(latency);
    if (_latencyHistory.length > _maxHistoryLength) {
      _latencyHistory.removeAt(0);
    }
  }
  /// Calculate connection quality based on average latency
  ConnectionQuality _calculateQuality() {
    if (_latencyHistory.isEmpty) return ConnectionQuality.unknown;
    
    final averageLatency = _latencyHistory.reduce((a, b) => a + b) / _latencyHistory.length;
    
    if (averageLatency < 100) return ConnectionQuality.excellent;
    if (averageLatency < 300) return ConnectionQuality.good;
    if (averageLatency < 600) return ConnectionQuality.fair;
    return ConnectionQuality.poor;
  }
  /// Get average latency
  double? get averageLatency {
    if (_latencyHistory.isEmpty) return null;
    return _latencyHistory.reduce((a, b) => a + b) / _latencyHistory.length;
  }
}
/// Connection quality enumeration
enum ConnectionQuality {
  excellent,
  good,
  fair,
  poor,
  unknown,
}
/// Offline Data Manager
class OfflineDataManager {
  static final OfflineDataManager _instance = OfflineDataManager._internal();
  factory OfflineDataManager() => _instance;
  OfflineDataManager._internal();
  final List<OfflineAction> _pendingActions = [];
  final NetworkManager _networkManager = NetworkManager();
  bool _isSyncInProgress = false;
  /// Add action to offline queue
  void addPendingAction(OfflineAction action) {
    _pendingActions.add(action);
  }
  /// Get pending actions count
  int get pendingActionsCount => _pendingActions.length;
  /// Check if there are pending actions
  bool get hasPendingActions => _pendingActions.isNotEmpty;
  /// Sync pending actions when network is available
  Future<void> syncPendingActions() async {
    if (_isSyncInProgress || !_networkManager.isConnected) return;
    
    _isSyncInProgress = true;
    
    try {
      final actionsToSync = List<OfflineAction>.from(_pendingActions);
      
      for (final action in actionsToSync) {
        try {
          await action.execute();
          _pendingActions.remove(action);
        } catch (e) {
          // Keep action in queue for next sync attempt
          print('Failed to sync action: ${action.type}, error: $e');
        }
      }
    } finally {
      _isSyncInProgress = false;
    }
  }
  /// Clear all pending actions
  void clearPendingActions() {
    _pendingActions.clear();
  }
}
/// Offline Action Model
class OfflineAction {
  final String id;
  final OfflineActionType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final Future<void> Function() execute;
  OfflineAction({
    required this.id,
    required this.type,
    required this.data,
    required this.execute,
  }) : timestamp = DateTime.now();
}
/// Offline action types
enum OfflineActionType {
  createItem,
  updateItem,
  deleteItem,
  sendMessage,
  joinGroup,
  leaveGroup,
  updateProfile,
}
/// Enhanced Cache Manager with Network Awareness
class NetworkAwareCacheManager {
  static final NetworkAwareCacheManager _instance = NetworkAwareCacheManager._internal();
  factory NetworkAwareCacheManager() => _instance;
  NetworkAwareCacheManager._internal();
  final Map<String, CacheEntry> _cache = {};
  final NetworkManager _networkManager = NetworkManager();
  /// Get cached data or fetch from network
  Future<T?> get<T>({
    required String key,
    required Future<T> Function() fetcher,
    Duration? maxAge,
    bool forceRefresh = false,
  }) async {
    final cacheEntry = _cache[key];
    final now = DateTime.now();
    
    // Check if we have valid cached data and network is available
    if (!forceRefresh && cacheEntry != null) {
      final age = now.difference(cacheEntry.timestamp);
      final isExpired = maxAge != null && age > maxAge;
      
      // Return cached data if not expired or network is not available
      if (!isExpired || !_networkManager.isConnected) {
        return cacheEntry.data as T?;
      }
    }
    // Fetch from network if available
    if (_networkManager.isConnected) {
      try {
        final data = await fetcher();
        _cache[key] = CacheEntry(data: data, timestamp: now);
        return data;
      } catch (e) {
        // Return cached data if network fails
        return cacheEntry?.data as T?;
      }
    }
    // Return cached data if network is not available
    return cacheEntry?.data as T?;
  }
  /// Store data in cache
  void put(String key, dynamic data) {
    _cache[key] = CacheEntry(data: data, timestamp: DateTime.now());
  }
  /// Remove cached data
  void remove(String key) {
    _cache.remove(key);
  }
  /// Clear all cached data
  void clear() {
    _cache.clear();
  }
  /// Get cache size
  int get size => _cache.length;
}
/// Cache entry model
class CacheEntry {
  final dynamic data;
  final DateTime timestamp;
  CacheEntry({required this.data, required this.timestamp});
}
/// Network-aware HTTP client extension
extension NetworkAwareHttp on http.Client {
  Future<http.Response> getWithRetry(
    Uri url, {
    Map<String, String>? headers,
    int maxRetries = 3,
  }) async {
    return RetryManager.executeWithRetry(
      () => get(url, headers: headers),
      maxRetries: maxRetries,
      shouldRetry: (error) => RetryManager.isRetryableError(error),
    );
  }
  Future<http.Response> postWithRetry(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    int maxRetries = 3,
  }) async {
    return RetryManager.executeWithRetry(
      () => post(url, headers: headers, body: body),
      maxRetries: maxRetries,
      shouldRetry: (error) => RetryManager.isRetryableError(error),
    );
  }
}