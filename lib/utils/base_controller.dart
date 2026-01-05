import 'package:flutter/material.dart';
import 'state_builder.dart';

/// Base controller for managing state, loading, and errors
abstract class BaseController<T> extends ChangeNotifier {
  ViewState _state = ViewState.loaded;
  dynamic _error;
  T? _data;
  bool _disposed = false;

  ViewState get state => _state;
  dynamic get error => _error;
  T? get data => _data;
  bool get isLoading => _state == ViewState.loading;
  bool get hasError => _state == ViewState.error;
  bool get isEmpty => _state == ViewState.empty;
  bool get isLoaded => _state == ViewState.loaded;

  /// Set loading state
  void setLoading() {
    if (!_disposed) {
      _state = ViewState.loading;
      _error = null;
      notifyListeners();
    }
  }

  /// Set loaded state
  void setLoaded() {
    if (!_disposed) {
      _state = ViewState.loaded;
      _error = null;
      notifyListeners();
    }
  }

  /// Set error state
  void setError(dynamic error) {
    if (!_disposed) {
      _state = ViewState.error;
      _error = error;
      notifyListeners();
    }
  }

  /// Set empty state
  void setEmpty() {
    if (!_disposed) {
      _state = ViewState.empty;
      _error = null;
      notifyListeners();
    }
  }

  /// Execute an async operation with automatic state management
  Future<T?> execute(
    Future<T> Function() operation, {
    bool showLoading = true,
    Function(T)? onSuccess,
    Function(dynamic)? onError,
    bool checkEmpty = false,
    bool Function(T)? isEmptyCheck,
  }) async {
    try {
      if (showLoading) {
        setLoading();
      }

      final result = await operation();

      // Store data
      _data = result as T?;

      // Check if result is empty (for lists, maps, etc.)
      if (checkEmpty && isEmptyCheck != null && isEmptyCheck(result)) {
        setEmpty();
      } else {
        setLoaded();
      }

      onSuccess?.call(result);
      return result;
    } catch (e) {
      setError(e);
      onError?.call(e);
      return null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }
}

/// Mixin for safe state updates in StatefulWidgets
mixin SafeStateMixin<T extends StatefulWidget> on State<T> {
  /// Safely call setState only if mounted
  void safeSetState(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  /// Execute async operation with loading state
  Future<void> executeWithLoading(
    Future<void> Function() operation, {
    bool Function()? canExecute,
  }) async {
    if (canExecute != null && !canExecute()) return;

    if (mounted) {
      setState(() {});
    }

    try {
      await operation();
    } finally {
      if (mounted) {
        setState(() {});
      }
    }
  }
}

/// Disposable resources tracker
class DisposableController {
  final List<VoidCallback> _disposables = [];
  bool _disposed = false;

  /// Add a disposable resource
  void addDisposable(VoidCallback disposer) {
    if (!_disposed) {
      _disposables.add(disposer);
    }
  }

  /// Add a TextEditingController
  void addController(TextEditingController controller) {
    addDisposable(controller.dispose);
  }

  /// Add a FocusNode
  void addFocusNode(FocusNode node) {
    addDisposable(node.dispose);
  }

  /// Add a ScrollController
  void addScrollController(ScrollController controller) {
    addDisposable(controller.dispose);
  }

  /// Add an AnimationController
  void addAnimationController(AnimationController controller) {
    addDisposable(controller.dispose);
  }

  /// Add a StreamSubscription
  void addStreamSubscription(dynamic subscription) {
    addDisposable(() => subscription.cancel());
  }

  /// Dispose all resources
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    for (var disposer in _disposables) {
      try {
        disposer();
      } catch (e) {
        debugPrint('Error disposing resource: $e');
      }
    }
    _disposables.clear();
  }
}
