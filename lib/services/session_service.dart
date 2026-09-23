import 'package:attendx/core/network/core_service.dart';

class SessionService extends CoreService {
  /// GET /sessions/today
  /// Today's sessions for the lecturer's courses.
  /// Backend returns: [ { courseId, courseCode, ... }, ... ]
  Future<APIResponse> fetchTodaySessions() async {
    return fetch('/sessions/today');
  }

  /// POST /sessions/start
  /// Body: { courseId }
  /// Backend returns: the session object (or the existing active one).
  Future<APIResponse> startSession(Map<String, dynamic> payload) async {
    return send('/sessions/start', body: payload, method: 'POST');
  }

  /// GET /sessions/:id
  /// Backend returns: the session object.
  Future<APIResponse> fetchSession(String id) async {
    return fetch('/sessions/$id');
  }

  /// GET /sessions/:id/qr
  /// Backend returns: { token, secondsUntilRefresh }
  Future<APIResponse> fetchSessionQr(String id) async {
    return fetch('/sessions/$id/qr');
  }

  /// POST /sessions/:id/pause
  Future<APIResponse> pauseSession(String id) async {
    return send('/sessions/$id/pause', method: 'POST');
  }

  /// POST /sessions/:id/resume
  Future<APIResponse> resumeSession(String id) async {
    return send('/sessions/$id/resume', method: 'POST');
  }

  /// POST /sessions/:id/end
  /// Backend returns: the summary object.
  Future<APIResponse> endSession(String id) async {
    return send('/sessions/$id/end', method: 'POST');
  }
}