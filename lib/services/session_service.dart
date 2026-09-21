import 'package:attendx/core/network/core_service.dart';

class SessionService extends CoreService {
  // GET /sessions/today
  // Today's sessions for the lecturer's courses
  Future<APIResponse> fetchTodaySessions() async {
    return fetch('/sessions/today');
  }

  // POST /sessions/start
  // Start or resume a live attendance session
  Future<APIResponse> startSession(
    Map<String, dynamic> payload,
  ) async {
    return send(
      '/sessions/start',
      body: payload,
      method: 'POST',
    );
  }

  // GET /sessions/:id
  // Get session with live present count
  Future<APIResponse> fetchSession(String id) async {
    return fetch('/sessions/$id');
  }

  // GET /sessions/:id/qr
  // Get current rotating QR token
  Future<APIResponse> fetchSessionQr(String id) async {
    return fetch('/sessions/$id/qr');
  }

  // POST /sessions/:id/pause
  // Pause attendance capture
  Future<APIResponse> pauseSession(String id) async {
    return send(
      '/sessions/$id/pause',
      method: 'POST',
    );
  }

  // POST /sessions/:id/resume
  // Resume a paused session
  Future<APIResponse> resumeSession(String id) async {
    return send(
      '/sessions/$id/resume',
      method: 'POST',
    );
  }

  // POST /sessions/:id/end
  // End session and get attendance summary
  Future<APIResponse> endSession(String id) async {
    return send(
      '/sessions/$id/end',
      method: 'POST',
    );
  }
}