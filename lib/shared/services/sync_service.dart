enum SyncState { idle, syncing, synced, offline }

/// Abstract contract for background sync of offline-saved attendance.
abstract class SyncService {
  Stream<SyncState> get syncState;
  Future<void> triggerSync();
  bool get isOnline;
}
