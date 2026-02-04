import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/env_config.dart';

/// Logging levels
enum LogLevel {
  debug(0, 'DEBUG'),
  info(1, 'INFO'),
  warning(2, 'WARN'),
  error(3, 'ERROR'),
  fatal(4, 'FATAL');

  final int priority;
  final String label;
  const LogLevel(this.priority, this.label);
}

/// Structured log entry
class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final String? tag;
  final Map<String, dynamic>? data;
  final String? stackTrace;

  LogEntry({
    required this.level,
    required this.message,
    this.tag,
    this.data,
    this.stackTrace,
  }) : timestamp = DateTime.now();

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'level': level.label,
    'tag': tag,
    'message': message,
    'data': data,
    'stackTrace': stackTrace,
  };

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('[${timestamp.toIso8601String()}] ');
    buffer.write('[${level.label}] ');
    if (tag != null) buffer.write('[$tag] ');
    buffer.write(message);
    if (data != null) buffer.write(' | ${jsonEncode(data)}');
    if (stackTrace != null) buffer.write('\n$stackTrace');
    return buffer.toString();
  }
}

/// App-wide logging service
class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() => _instance;
  AppLogger._internal();

  // Configuration
  LogLevel _minLevel = EnvConfig.enableDebugMode ? LogLevel.debug : LogLevel.info;
  final int _maxLogEntries = 1000;
  final List<LogEntry> _logBuffer = [];
  final List<void Function(LogEntry)> _listeners = [];
  
  // File logging
  File? _logFile;
  bool _initialized = false;

  /// Initialize the logger
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      final tempDir = Directory.systemTemp;
      final logDir = Directory('${tempDir.path}/lendly_logs');
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }
      
      final date = DateTime.now().toIso8601String().split('T')[0];
      _logFile = File('${logDir.path}/lendly_$date.log');
      
      // Clean old log files
      await _cleanOldLogs(logDir);
      
      _initialized = true;
      info('Logger initialized', tag: 'AppLogger');
    } catch (e) {
      // Logger init failure - can only print to console
      print('AppLogger initialization failed: $e');
    }
  }

  /// Set minimum log level
  void setMinLevel(LogLevel level) {
    _minLevel = level;
  }

  /// Add log listener
  void addListener(void Function(LogEntry) listener) {
    _listeners.add(listener);
  }

  /// Remove log listener
  void removeListener(void Function(LogEntry) listener) {
    _listeners.remove(listener);
  }

  /// Log debug message
  void debug(String message, {String? tag, Map<String, dynamic>? data}) {
    _log(LogLevel.debug, message, tag: tag, data: data);
  }

  /// Log info message
  void info(String message, {String? tag, Map<String, dynamic>? data}) {
    _log(LogLevel.info, message, tag: tag, data: data);
  }

  /// Log warning message
  void warning(String message, {String? tag, Map<String, dynamic>? data}) {
    _log(LogLevel.warning, message, tag: tag, data: data);
  }

  /// Log error message
  void error(
    String message, {
    String? tag,
    Map<String, dynamic>? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      LogLevel.error,
      message,
      tag: tag,
      data: {
        ...?data,
        if (error != null) 'error': error.toString(),
      },
      stackTrace: stackTrace?.toString(),
    );
  }

  /// Log fatal message
  void fatal(
    String message, {
    String? tag,
    Map<String, dynamic>? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      LogLevel.fatal,
      message,
      tag: tag,
      data: {
        ...?data,
        if (error != null) 'error': error.toString(),
      },
      stackTrace: stackTrace?.toString(),
    );
  }

  /// Log API request
  void logApiRequest(
    String method,
    String url, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) {
    if (!EnvConfig.enableDebugMode) return;
    
    debug(
      'API Request: $method $url',
      tag: 'API',
      data: {
        'method': method,
        'url': url,
        if (body != null) 'body': _sanitizeData(body),
        if (headers != null) 'headers': _sanitizeData(headers),
      },
    );
  }

  /// Log API response
  void logApiResponse(
    String method,
    String url,
    int statusCode,
    Duration duration, {
    dynamic response,
  }) {
    final level = statusCode >= 400 ? LogLevel.error : LogLevel.debug;
    
    _log(
      level,
      'API Response: $method $url [$statusCode] ${duration.inMilliseconds}ms',
      tag: 'API',
      data: {
        'statusCode': statusCode,
        'duration': duration.inMilliseconds,
        if (EnvConfig.enableDebugMode && response != null)
          'response': _sanitizeData(response),
      },
    );
  }

  /// Log navigation event
  void logNavigation(String from, String to, {Map<String, dynamic>? params}) {
    debug(
      'Navigation: $from -> $to',
      tag: 'NAV',
      data: params,
    );
  }

  /// Log user action
  void logUserAction(String action, {Map<String, dynamic>? data}) {
    info(
      'User Action: $action',
      tag: 'USER',
      data: data,
    );
  }

  /// Log performance metric
  void logPerformance(String operation, Duration duration, {Map<String, dynamic>? data}) {
    final level = duration.inMilliseconds > 1000 ? LogLevel.warning : LogLevel.debug;
    
    _log(
      level,
      'Performance: $operation took ${duration.inMilliseconds}ms',
      tag: 'PERF',
      data: {
        'operation': operation,
        'durationMs': duration.inMilliseconds,
        ...?data,
      },
    );
  }

  /// Get recent logs
  List<LogEntry> getRecentLogs({int count = 100, LogLevel? minLevel}) {
    var logs = _logBuffer;
    
    if (minLevel != null) {
      logs = logs.where((l) => l.level.priority >= minLevel.priority).toList();
    }
    
    return logs.reversed.take(count).toList();
  }

  /// Export logs as string
  Future<String> exportLogs() async {
    final buffer = StringBuffer();
    buffer.writeln('=== Lendly App Logs ===');
    buffer.writeln('Exported: ${DateTime.now().toIso8601String()}');
    buffer.writeln('Environment: ${EnvConfig.environment}');
    buffer.writeln('App Version: ${EnvConfig.appVersion}');
    buffer.writeln('========================\n');
    
    for (final entry in _logBuffer) {
      buffer.writeln(entry.toString());
    }
    
    return buffer.toString();
  }

  /// Save logs to SharedPreferences (for crash reports)
  Future<void> persistLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logsJson = _logBuffer.take(200).map((e) => e.toJson()).toList();
      await prefs.setString('crash_logs', jsonEncode(logsJson));
    } catch (e) {
      // Silently fail - don't want log persistence to crash app
    }
  }

  /// Get persisted logs (after crash)
  Future<List<LogEntry>?> getPersistedLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logsJson = prefs.getString('crash_logs');
      if (logsJson != null) {
        final list = jsonDecode(logsJson) as List;
        await prefs.remove('crash_logs');
        return list.map((e) => _logEntryFromJson(e)).toList();
      }
    } catch (e) {
      // Silently fail - don't want log retrieval to crash app
    }
    return null;
  }

  /// Clear all logs
  void clearLogs() {
    _logBuffer.clear();
  }

  // Private methods

  void _log(
    LogLevel level,
    String message, {
    String? tag,
    Map<String, dynamic>? data,
    String? stackTrace,
  }) {
    if (level.priority < _minLevel.priority) return;
    
    final entry = LogEntry(
      level: level,
      message: message,
      tag: tag,
      data: data,
      stackTrace: stackTrace,
    );
    
    // Add to buffer
    _logBuffer.add(entry);
    
    // Trim buffer if too large
    while (_logBuffer.length > _maxLogEntries) {
      _logBuffer.removeAt(0);
    }
    
    // Console output in debug mode
    if (kDebugMode || EnvConfig.enableDebugMode) {
      _printToConsole(entry);
    }
    
    // Write to file
    _writeToFile(entry);
    
    // Notify listeners
    for (final listener in _listeners) {
      listener(entry);
    }
  }

  dynamic _sanitizeData(dynamic value) {
    if (value is Map) {
      return value.map((key, val) => MapEntry(key, _sanitizeEntry(key, val)));
    }
    if (value is List) {
      return value.map(_sanitizeData).toList();
    }
    if (value is String) {
      return value;
    }
    return value;
  }

  dynamic _sanitizeEntry(dynamic key, dynamic value) {
    if (key is String) {
      return _redactIfSensitiveKey(key, value);
    }
    return _sanitizeData(value);
  }

  dynamic _redactIfSensitiveKey(String key, dynamic value) {
    final loweredKey = key.toLowerCase();
    final sensitiveKeys = [
      'authorization',
      'token',
      'id_token',
      'refresh_token',
      'email',
      'uid',
      'user_id',
      'password',
    ];

    if (sensitiveKeys.any(loweredKey.contains)) {
      return 'REDACTED';
    }

    if (value is String) {
      if (value.contains('Bearer ')) {
        return 'REDACTED';
      }
    }

    return _sanitizeData(value);
  }

  void _printToConsole(LogEntry entry) {
    final color = switch (entry.level) {
      LogLevel.debug => '\x1B[37m', // White
      LogLevel.info => '\x1B[34m',  // Blue
      LogLevel.warning => '\x1B[33m', // Yellow
      LogLevel.error => '\x1B[31m', // Red
      LogLevel.fatal => '\x1B[35m', // Magenta
    };
    const reset = '\x1B[0m';
    
  }

  Future<void> _writeToFile(LogEntry entry) async {
    if (_logFile == null) return;
    
    try {
      await _logFile!.writeAsString(
        '${entry.toString()}\n',
        mode: FileMode.append,
      );
    } catch (e) {
      // Silent fail for file writing
    }
  }

  Future<void> _cleanOldLogs(Directory logDir) async {
    try {
      final now = DateTime.now();
      await for (final entity in logDir.list()) {
        if (entity is File) {
          final stat = await entity.stat();
          if (now.difference(stat.modified).inDays > 7) {
            await entity.delete();
          }
        }
      }
    } catch (e) {
      // Silent fail
    }
  }

  LogEntry _logEntryFromJson(Map<String, dynamic> json) {
    return LogEntry(
      level: LogLevel.values.firstWhere(
        (l) => l.label == json['level'],
        orElse: () => LogLevel.info,
      ),
      message: json['message'] ?? '',
      tag: json['tag'],
      data: json['data'],
      stackTrace: json['stackTrace'],
    );
  }
}

/// Convenient global logger instance
final logger = AppLogger();

/// Mixin for easy logging in classes
mixin LoggerMixin {
  String get logTag => runtimeType.toString();
  
  void logDebug(String message, {Map<String, dynamic>? data}) {
    logger.debug(message, tag: logTag, data: data);
  }
  
  void logInfo(String message, {Map<String, dynamic>? data}) {
    logger.info(message, tag: logTag, data: data);
  }
  
  void logWarning(String message, {Map<String, dynamic>? data}) {
    logger.warning(message, tag: logTag, data: data);
  }
  
  void logError(
    String message, {
    Map<String, dynamic>? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    logger.error(message, tag: logTag, data: data, error: error, stackTrace: stackTrace);
  }
}
