import 'dart:async';

/// Debouncer to prevent rapid API calls
/// Useful for search inputs, scroll events, etc.
class RequestDebouncer {
  final Duration duration;
  Timer? _timer;
  
  RequestDebouncer({this.duration = const Duration(milliseconds: 300)});
  
  /// Call this method with your callback
  /// The callback will only execute after [duration] has passed
  /// without any new calls
  void run(VoidCallback callback) {
    _timer?.cancel();
    _timer = Timer(duration, callback);
  }
  
  /// Cancel any pending debounced call
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
  
  /// Dispose the debouncer
  void dispose() {
    cancel();
  }
}

typedef VoidCallback = void Function();

/// Throttler to limit API call frequency
/// Allows at most one call per [duration] period
class RequestThrottler {
  final Duration duration;
  DateTime? _lastCall;
  
  RequestThrottler({this.duration = const Duration(milliseconds: 500)});
  
  /// Execute callback only if enough time has passed since last call
  bool run(VoidCallback callback) {
    final now = DateTime.now();
    if (_lastCall == null || now.difference(_lastCall!) >= duration) {
      _lastCall = now;
      callback();
      return true;
    }
    return false;
  }
  
  /// Force reset the throttler
  void reset() {
    _lastCall = null;
  }
}

/// Request deduplicator to prevent duplicate concurrent requests
/// Same request will only run once, subsequent calls will wait for result
class RequestDeduplicator<T> {
  final Map<String, Future<T>> _pendingRequests = {};
  
  /// Execute a request or return existing pending result
  Future<T> dedupe(String key, Future<T> Function() requestFn) async {
    // If there's already a pending request with same key, return its future
    if (_pendingRequests.containsKey(key)) {
      return _pendingRequests[key]!;
    }
    
    // Create new request
    final future = requestFn();
    _pendingRequests[key] = future;
    
    try {
      final result = await future;
      return result;
    } finally {
      _pendingRequests.remove(key);
    }
  }
  
  /// Check if a request is currently pending
  bool isPending(String key) => _pendingRequests.containsKey(key);
  
  /// Cancel/clear all pending request references
  void clear() {
    _pendingRequests.clear();
  }
}

/// Batch multiple requests into one
class RequestBatcher<T> {
  final Duration delay;
  final Future<Map<String, T>> Function(List<String> keys) batchFn;
  
  final Map<String, Completer<T>> _pending = {};
  Timer? _timer;
  final List<String> _keys = [];
  
  RequestBatcher({
    this.delay = const Duration(milliseconds: 50),
    required this.batchFn,
  });
  
  /// Add a key to the batch and get a future for its result
  Future<T> add(String key) {
    if (_pending.containsKey(key)) {
      return _pending[key]!.future;
    }
    
    final completer = Completer<T>();
    _pending[key] = completer;
    _keys.add(key);
    
    _timer?.cancel();
    _timer = Timer(delay, _executeBatch);
    
    return completer.future;
  }
  
  void _executeBatch() async {
    if (_keys.isEmpty) return;
    
    final keysToProcess = List<String>.from(_keys);
    final completersToProcess = Map<String, Completer<T>>.from(_pending);
    
    _keys.clear();
    _pending.clear();
    
    try {
      final results = await batchFn(keysToProcess);
      for (final key in keysToProcess) {
        if (results.containsKey(key)) {
          completersToProcess[key]?.complete(results[key]);
        } else {
          completersToProcess[key]?.completeError(
            Exception('No result for key: $key'),
          );
        }
      }
    } catch (e) {
      for (final completer in completersToProcess.values) {
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
      }
    }
  }
  
  void dispose() {
    _timer?.cancel();
    _pending.clear();
    _keys.clear();
  }
}
