import 'dart:async';

enum SyncState {
  synced('Synced', 'All study data is saved to your cloud account', '🟢'),
  syncing('Syncing', 'Saving your study progress...', '🟡'),
  offline('Offline', 'Could not reach the cloud. Changes will retry on next save.', '🔴');

  final String label;
  final String description;
  final String icon;
  const SyncState(this.label, this.description, this.icon);
}

/// Tracks the real cloud-save status (Firestore).
class SyncService {
  SyncState _state = SyncState.synced;
  String? _lastError;
  DateTime? _lastSyncedAt;

  SyncState get state => _state;
  bool get isOnline => _state != SyncState.offline;
  String? get lastError => _lastError;
  DateTime? get lastSyncedAt => _lastSyncedAt;

  final _controller = StreamController<SyncState>.broadcast();
  Stream<SyncState> get syncStream => _controller.stream;

  void _set(SyncState s) {
    _state = s;
    if (!_controller.isClosed) _controller.add(s);
  }

  /// Runs a cloud task and updates the badge state around it.
  Future<bool> run(Future<void> Function() task) async {
    _set(SyncState.syncing);
    try {
      await task().timeout(const Duration(seconds: 20));
      _lastError = null;
      _lastSyncedAt = DateTime.now();
      _set(SyncState.synced);
      return true;
    } catch (e) {
      _lastError = e.toString();
      _set(SyncState.offline);
      return false;
    }
  }

  void markOffline(String error) {
    _lastError = error;
    _set(SyncState.offline);
  }

  void markSynced() {
    _lastError = null;
    _lastSyncedAt = DateTime.now();
    _set(SyncState.synced);
  }

  void dispose() {
    _controller.close();
  }
}
