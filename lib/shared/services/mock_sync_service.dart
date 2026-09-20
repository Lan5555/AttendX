import 'dart:async';
import 'sync_service.dart';

class MockSyncService implements SyncService {
  final StreamController<SyncState> _controller = StreamController<SyncState>.broadcast();
  bool _isOnline = true;

  @override
  bool get isOnline => _isOnline;

  @override
  Stream<SyncState> get syncState => _controller.stream;

  @override
  Future<void> triggerSync() async {
    _controller.add(SyncState.syncing);
    await Future.delayed(const Duration(seconds: 2));
    _controller.add(SyncState.synced);
  }

  void setOnline(bool online) {
    _isOnline = online;
    _controller.add(online ? SyncState.synced : SyncState.offline);
  }
}
