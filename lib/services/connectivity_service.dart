import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

/// Network connectivity status
enum ConnectivityStatus {
  online,
  offline,
  slow,
}

/// Network connectivity monitoring service
class ConnectivityService extends ChangeNotifier {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  ConnectivityStatus _status = ConnectivityStatus.online;
  Timer? _checkTimer;
  DateTime? _lastOnlineTime;
  int _consecutiveFailures = 0;
  final List<void Function(ConnectivityStatus)> _listeners = [];

  /// Current connectivity status
  ConnectivityStatus get status => _status;
  
  /// Whether device is online
  bool get isOnline => _status == ConnectivityStatus.online;
  
  /// Whether device is offline
  bool get isOffline => _status == ConnectivityStatus.offline;
  
  /// Last time device was online
  DateTime? get lastOnlineTime => _lastOnlineTime;

  /// Initialize connectivity monitoring
  Future<void> initialize() async {
    await _checkConnectivity();
    _startPeriodicCheck();
  }

  /// Add connectivity listener
  void addConnectivityListener(void Function(ConnectivityStatus) listener) {
    _listeners.add(listener);
  }

  /// Remove connectivity listener
  void removeConnectivityListener(void Function(ConnectivityStatus) listener) {
    _listeners.remove(listener);
  }

  /// Force connectivity check
  Future<ConnectivityStatus> checkNow() async {
    return await _checkConnectivity();
  }

  /// Dispose resources
  void dispose() {
    _checkTimer?.cancel();
    _listeners.clear();
  }

  // Private methods

  Future<ConnectivityStatus> _checkConnectivity() async {
    final oldStatus = _status;
    
    try {
      final stopwatch = Stopwatch()..start();
      
      // Try to resolve a DNS lookup
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      
      stopwatch.stop();
      
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        _consecutiveFailures = 0;
        _lastOnlineTime = DateTime.now();
        
        // Check if connection is slow (> 2 seconds for DNS)
        if (stopwatch.elapsedMilliseconds > 2000) {
          _status = ConnectivityStatus.slow;
        } else {
          _status = ConnectivityStatus.online;
        }
      } else {
        _handleOffline();
      }
    } on SocketException {
      _handleOffline();
    } on TimeoutException {
      _handleOffline();
    } catch (_) {
      _handleOffline();
    }
    
    if (oldStatus != _status) {
      _notifyListeners();
    }
    
    return _status;
  }

  void _handleOffline() {
    _consecutiveFailures++;
    
    // Only mark as offline after 2 consecutive failures
    if (_consecutiveFailures >= 2) {
      _status = ConnectivityStatus.offline;
    }
  }

  void _startPeriodicCheck() {
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(
      Duration(seconds: _status == ConnectivityStatus.offline ? 10 : 30),
      (_) => _checkConnectivity(),
    );
  }

  void _notifyListeners() {
    notifyListeners();
    for (final listener in _listeners) {
      listener(_status);
    }
    
    // Adjust check frequency based on status
    _startPeriodicCheck();
  }
}

/// Connectivity-aware widget wrapper
class ConnectivityAware extends StatefulWidget {
  final Widget child;
  final Widget? offlineWidget;
  final bool showBanner;

  const ConnectivityAware({
    super.key,
    required this.child,
    this.offlineWidget,
    this.showBanner = true,
  });

  @override
  State<ConnectivityAware> createState() => _ConnectivityAwareState();
}

class _ConnectivityAwareState extends State<ConnectivityAware> {
  final _connectivity = ConnectivityService();

  @override
  void initState() {
    super.initState();
    _connectivity.addListener(_onConnectivityChange);
  }

  @override
  void dispose() {
    _connectivity.removeListener(_onConnectivityChange);
    super.dispose();
  }

  void _onConnectivityChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.showBanner && _connectivity.isOffline)
          _OfflineBanner(),
        if (widget.showBanner && _connectivity.status == ConnectivityStatus.slow)
          _SlowConnectionBanner(),
        Expanded(
          child: _connectivity.isOffline && widget.offlineWidget != null
              ? widget.offlineWidget!
              : widget.child,
        ),
      ],
    );
  }
}

/// Offline banner widget
class _OfflineBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.red[700],
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Text(
            'No internet connection',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

/// Slow connection banner widget
class _SlowConnectionBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      color: Colors.orange[700],
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.signal_cellular_connected_no_internet_4_bar, 
               color: Colors.white, size: 16),
          SizedBox(width: 8),
          Text(
            'Slow connection',
            style: TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Mixin for connectivity-aware widgets
mixin ConnectivityMixin<T extends StatefulWidget> on State<T> {
  final _connectivity = ConnectivityService();
  
  bool get isOnline => _connectivity.isOnline;
  bool get isOffline => _connectivity.isOffline;
  ConnectivityStatus get connectivityStatus => _connectivity.status;
  
  @override
  void initState() {
    super.initState();
    _connectivity.addConnectivityListener(_onConnectivityChange);
  }
  
  @override
  void dispose() {
    _connectivity.removeConnectivityListener(_onConnectivityChange);
    super.dispose();
  }
  
  void _onConnectivityChange(ConnectivityStatus status) {
    if (mounted) {
      onConnectivityChange(status);
    }
  }
  
  /// Override to handle connectivity changes
  void onConnectivityChange(ConnectivityStatus status) {
    setState(() {});
  }
}
