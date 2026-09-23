import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../services/session_service.dart';
import '../shared/models/attendance_session.dart';

class SessionController extends ChangeNotifier {
  SessionController({SessionService? service})
      : _service = service ?? SessionService();

  final SessionService _service;

  Timer? _qrTimer;
  Timer? _pollTimer;

  // ── State ────────────────────────────────────────────────────────────

  List<AttendanceSession> _todaySessions = [];
  List<AttendanceSession> get todaySessions => _todaySessions;

  AttendanceSession? _activeSession;
  AttendanceSession? get activeSession => _activeSession;

  int _presentCount = 0;
  int get presentCount => _presentCount;

  String _qrToken = '';
  String get qrToken => _qrToken;

  int _secondsUntilRefresh = 0;
  int get secondsUntilRefresh => _secondsUntilRefresh;

  bool _isLoadingToday = false;
  bool get isLoadingToday => _isLoadingToday;

  bool _isStarting = false;
  bool get isStarting => _isStarting;

  bool _isEnding = false;
  bool get isEnding => _isEnding;

  String? _error;
  String? get error => _error;

  bool get isPaused => _activeSession?.status == SessionStatus.paused;
  bool get isActive => _activeSession?.status == SessionStatus.active;

  // ── Safe notify ──────────────────────────────────────────────────────

  /// Notifies listeners, but defers until after the current frame if a
  /// build is in progress. Prevents "setState() called during build".
  void _safeNotify() {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance
          .addPostFrameCallback((_) => notifyListeners());
    } else {
      notifyListeners();
    }
  }

  // ── Today's sessions ─────────────────────────────────────────────────

  Future<void> fetchTodaySessions() async {
    _isLoadingToday = true;
    _error = null;
    _safeNotify();

    final response = await _service.fetchTodaySessions();

    if (!response.success) {
      _isLoadingToday = false;
      _error = response.message;
      _safeNotify();
      return;
    }

    final raw = response.data['items'];
    final list = raw is List ? raw : const [];

    _todaySessions = list
        .whereType<Map<String, dynamic>>()
        .map(AttendanceSession.fromJson)
        .toList();

    _isLoadingToday = false;
    _safeNotify();
  }

  // ── Session lifecycle ────────────────────────────────────────────────

  Future<bool> startSession(String courseId) async {
    _isStarting = true;
    _error = null;
    _safeNotify();

    final response = await _service.startSession({'courseId': courseId});

    if (!response.success) {
      _isStarting = false;
      _error = response.message;
      _safeNotify();
      return false;
    }

    _activeSession = AttendanceSession.fromJson(response.data);
    _presentCount = _activeSession!.presentCount;
    _isStarting = false;
    _safeNotify();

    await _fetchQr();
    _startTimers();
    return true;
  }

  Future<AttendanceSession?> endSession() async {
    final session = _activeSession;
    if (session == null) return null;

    _isEnding = true;
    _error = null;
    _safeNotify();

    _stopTimers();

    final response = await _service.endSession(session.id);

    if (!response.success) {
      _isEnding = false;
      _error = response.message;
      _safeNotify();
      _startTimers();
      return null;
    }

    final summary = session.copyWith(
      status: SessionStatus.completed,
      presentCount: response.data['presentCount'] as int? ?? _presentCount,
      endedAt: DateTime.tryParse(
        response.data['endedAt'] as String? ?? '',
      ),
    );

    _activeSession = summary;
    _isEnding = false;
    _safeNotify();
    return summary;
  }

  Future<void> pauseSession() async {
    final session = _activeSession;
    if (session == null) return;

    final response = await _service.pauseSession(session.id);
    if (!response.success) {
      _error = response.message;
      _safeNotify();
      return;
    }

    _activeSession = AttendanceSession.fromJson(response.data);
    _qrTimer?.cancel();
    _qrTimer = null;
    _qrToken = '';
    _secondsUntilRefresh = 0;
    _safeNotify();
  }

  Future<void> resumeSession() async {
    final session = _activeSession;
    if (session == null) return;

    final response = await _service.resumeSession(session.id);
    if (!response.success) {
      _error = response.message;
      _safeNotify();
      return;
    }

    _activeSession = AttendanceSession.fromJson(response.data);
    _safeNotify();

    await _fetchQr();
    _startQrTimer();
  }

  Future<void> togglePause() async {
    if (isPaused) {
      await resumeSession();
    } else {
      await pauseSession();
    }
  }

  void clearActiveSession() {
    _stopTimers();
    _activeSession = null;
    _presentCount = 0;
    _qrToken = '';
    _secondsUntilRefresh = 0;
    _error = null;
    _safeNotify();
  }

  // ── Timers ───────────────────────────────────────────────────────────

  void _startTimers() {
    _startQrTimer();
    _startPollTimer();
  }

  void _stopTimers() {
    _qrTimer?.cancel();
    _qrTimer = null;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _startQrTimer() {
    _qrTimer?.cancel();
    _qrTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_secondsUntilRefresh > 1) {
        _secondsUntilRefresh--;
        _safeNotify();
      } else {
        await _fetchQr();
      }
    });
  }

  void _startPollTimer() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await _refreshActiveSession();
    });
  }

  // ── Internal fetches ─────────────────────────────────────────────────
Future<void> _fetchQr() async {
  final session = _activeSession;
  if (session == null) return;

  final response = await _service.fetchSessionQr(session.id);
  if (!response.success) return;

  final payload = response.data['qrPayload'] as String?;
  final token = response.data['token'] as String? ?? '';

  _qrToken = payload ?? token;   // ← prefer payload
  _secondsUntilRefresh =
      response.data['secondsUntilRefresh'] as int? ?? 8;
  _safeNotify();
}

  Future<void> _refreshActiveSession() async {
    final session = _activeSession;
    if (session == null) return;

    final response = await _service.fetchSession(session.id);
    if (!response.success) return;

    _activeSession = AttendanceSession.fromJson(response.data);
    _presentCount = _activeSession!.presentCount;
    _safeNotify();
  }

  @override
  void dispose() {
    _stopTimers();
    super.dispose();
  }
}