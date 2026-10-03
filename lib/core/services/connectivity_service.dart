import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Exposes online/offline state so the UI can show friendly banners and
/// pause retryable work when the device is clearly offline.
class ConnectivityService {
  ConnectivityService() {
    _init();
  }

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isOnline = true;

  /// Emits `true` when the device has a network connection.
  Stream<bool> get onStatusChange => _controller.stream;

  bool get isOnline => _isOnline;

  Future<void> _init() async {
    try {
      final List<ConnectivityResult> results = await _connectivity
          .checkConnectivity();
      _isOnline = _hasNetwork(results);
      _controller.add(_isOnline);

      _subscription = _connectivity.onConnectivityChanged.listen((
        List<ConnectivityResult> results,
      ) {
        _isOnline = _hasNetwork(results);
        if (!_controller.isClosed) _controller.add(_isOnline);
      });
    } catch (_) {
      // If the platform channel is unavailable, assume online and let the
      // individual requests surface their own errors.
      _isOnline = true;
    }
  }

  static bool _hasNetwork(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    // `none` means no transport at all.
    return !results.contains(ConnectivityResult.none);
  }

  Future<bool> refresh() async {
    try {
      final List<ConnectivityResult> results = await _connectivity
          .checkConnectivity();
      _isOnline = _hasNetwork(results);
      if (!_controller.isClosed) _controller.add(_isOnline);
    } catch (_) {
      // Ignore — the cached value stands.
    }
    return _isOnline;
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _controller.close();
  }
}
