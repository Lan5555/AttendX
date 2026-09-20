import '../models/attendance_session.dart';

/// Abstract lecturer session contract — starting, pausing, ending
/// a live attendance session and streaming live counts.
abstract class SessionService {
  Future<List<AttendanceSession>> getTodaySessions();
  Future<AttendanceSession> startSession(String courseId);
  Future<AttendanceSession> pauseSession(String sessionId);
  Future<AttendanceSession> endSession(String sessionId);
  Stream<AttendanceSession> watchSession(String sessionId);
}
