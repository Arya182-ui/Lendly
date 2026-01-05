enum ViewState {
  idle,
  loading,
  loaded,
  empty,
  busy,
  error,
  success
}

/// Utility class for building UI based on view states
class StateBuilder {
  static bool isIdle(ViewState state) => state == ViewState.idle;
  static bool isLoading(ViewState state) => state == ViewState.loading;
  static bool isLoaded(ViewState state) => state == ViewState.loaded;
  static bool isEmpty(ViewState state) => state == ViewState.empty;
  static bool isBusy(ViewState state) => state == ViewState.busy;
  static bool hasError(ViewState state) => state == ViewState.error;
  static bool isSuccess(ViewState state) => state == ViewState.success;
}