import 'dart:async';
import 'dart:math';
import '../models/attendance_session.dart';
import '../mock/mock_data.dart';
import 'session_service.dart';

class MockSessionService implements SessionService {
  final Map<String, AttendanceSession> _sessions = {};
  final Map<String, StreamController<AttendanceSession>> _controllers = {};
  final Random _rand = Random();

  @override
  Future<List<AttendanceSession>> getTodaySessions() async {
    await Future.delayed(const Duration(milliseconds: 600));
    return [MockData.todaySessionForCsc416];
  }

  @override
  Future<AttendanceSession> startSession(String courseId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final base = MockData.todaySessionForCsc416;
    final session = base.copyWith(
      status: SessionStatus.active,
      startedAt: DateTime.now(),
      qrPayload: _generateQrPayload(),
      presentCount: 0,
    );
    _sessions[session.id] = session;
    _startTicking(session.id);
    return session;
  }

  @override
  Future<AttendanceSession> pauseSession(String sessionId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final s = _sessions[sessionId];
    if (s == null) throw Exception('Session not found');
    final updated = s.copyWith(status: SessionStatus.paused);
    _sessions[sessionId] = updated;
    _controllers[sessionId]?.add(updated);
    return updated;
  }

  @override
  Future<AttendanceSession> endSession(String sessionId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final s = _sessions[sessionId];
    if (s == null) throw Exception('Session not found');
    final updated = s.copyWith(status: SessionStatus.completed, endedAt: DateTime.now());
    _sessions[sessionId] = updated;
    _controllers[sessionId]?.add(updated);
    _controllers[sessionId]?.close();
    _controllers.remove(sessionId);
    return updated;
  }

  @override
  Stream<AttendanceSession> watchSession(String sessionId) {
    _controllers[sessionId] ??= StreamController<AttendanceSession>.broadcast();
    return _controllers[sessionId]!.stream;
  }

  void _startTicking(String sessionId) {
    _controllers[sessionId] ??= StreamController<AttendanceSession>.broadcast();
    Timer.periodic(const Duration(seconds: 8), (timer) {
      final s = _sessions[sessionId];
      if (s == null || s.status != SessionStatus.active) {
        timer.cancel();
        return;
      }
      final newPresent = min(s.totalStudents, s.presentCount + 1 + _rand.nextInt(4));
      final updated = s.copyWith(presentCount: newPresent, qrPayload: _generateQrPayload());
      _sessions[sessionId] = updated;
      _controllers[sessionId]?.add(updated);
    });
  }

  String _generateQrPayload() {
    final rand = Random.secure();
    return List.generate(24, (_) => rand.nextInt(16).toRadixString(16)).join();
  }
}
