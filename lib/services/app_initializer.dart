import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../config/env_config.dart';
import 'app_logger.dart';
import 'connectivity_service.dart';
import 'data_cache_manager.dart';
import 'image_cache_service.dart';
import 'session_service.dart';

/// App initialization service
/// Handles all startup tasks in a centralized manner
class AppInitializer {
  static bool _initialized = false;
  static final List<String> _initErrors = [];

  /// Initialize all app services
  static Future<void> initialize() async {
    if (_initialized) return;

    final stopwatch = Stopwatch()..start();
    
    try {
      // Print environment config in debug mode
      EnvConfig.printConfig();

      // Initialize services in parallel where possible
      await Future.wait([
        _initializeLogger(),
        _initializeCache(),
        _initializeImageCache(),
        _initializeConnectivity(),
      ]);

      // Initialize session (depends on cache being ready)
      await _initializeSession();

      stopwatch.stop();
      logger.info(
        'App initialized successfully',
        tag: 'AppInitializer',
        data: {'durationMs': stopwatch.elapsedMilliseconds},
      );

      _initialized = true;
    } catch (e, stack) {
      stopwatch.stop();
      logger.fatal(
        'App initialization failed',
        tag: 'AppInitializer',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Check if app is initialized
  static bool get isInitialized => _initialized;

  /// Get initialization errors
  static List<String> get initErrors => List.unmodifiable(_initErrors);

  // Private initialization methods

  static Future<void> _initializeLogger() async {
    try {
      await AppLogger().initialize();
      logger.info('Logger initialized', tag: 'AppInitializer');
    } catch (e) {
      _initErrors.add('Logger: $e');
    }
  }

  static Future<void> _initializeCache() async {
    try {
      await DataCacheManager.initialize();
      logger.info('Cache manager initialized', tag: 'AppInitializer');
    } catch (e) {
      _initErrors.add('Cache: $e');
      logger.warning('Cache initialization failed', tag: 'AppInitializer', data: {'error': e.toString()});
    }
  }

  static Future<void> _initializeImageCache() async {
    try {
      await ImageCacheService().initialize();
      logger.info('Image cache initialized', tag: 'AppInitializer');
    } catch (e) {
      _initErrors.add('ImageCache: $e');
      logger.warning('Image cache initialization failed', tag: 'AppInitializer', data: {'error': e.toString()});
    }
  }

  static Future<void> _initializeConnectivity() async {
    try {
      await ConnectivityService().initialize();
      logger.info('Connectivity service initialized', tag: 'AppInitializer');
    } catch (e) {
      _initErrors.add('Connectivity: $e');
      logger.warning('Connectivity service initialization failed', tag: 'AppInitializer', data: {'error': e.toString()});
    }
  }

  static Future<void> _initializeSession() async {
    try {
      // Load verification status from storage
      await SessionService.loadVerificationStatus();
      
      final uid = await SessionService.getUid();
      
      if (uid != null && uid.isNotEmpty) {
        logger.info('Found existing session', tag: 'AppInitializer', data: {'uid': uid});
      } else {
        logger.info('No existing session found', tag: 'AppInitializer');
      }
    } catch (e) {
      _initErrors.add('Session: $e');
      logger.warning('Session initialization failed', tag: 'AppInitializer', data: {'error': e.toString()});
    }
  }

  /// Cleanup resources (call on app exit)
  static Future<void> dispose() async {
    try {
      // Persist logs before exit
      await logger.persistLogs();
      

      // API client cleanup handled elsewhere

      // Dispose connectivity service
      ConnectivityService().dispose();
      
      logger.info('App disposed successfully', tag: 'AppInitializer');
    } catch (e) {
    }
  }

  /// Get app status for debugging
  static Map<String, dynamic> getStatus() {
    return {
      'initialized': _initialized,
      'errors': _initErrors,
      'environment': EnvConfig.environment,
      'apiBaseUrl': EnvConfig.apiBaseUrl,
      'isOnline': ConnectivityService().isOnline,
      'debugMode': EnvConfig.enableDebugMode,
    };
  }
}

/// Startup error widget
class StartupErrorWidget extends StatelessWidget {
  final String error;
  final VoidCallback? onRetry;

  const StartupErrorWidget({
    super.key,
    required this.error,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Failed to Start',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 24),
                if (onRetry != null)
                  ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
