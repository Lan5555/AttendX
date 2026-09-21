import 'package:attendx/core/network/core_service.dart';

class AttendanceService extends CoreService {
  // POST /attendance/mark
  // Mark attendance for current student
  Future<APIResponse> markAttendance(
    Map<String, dynamic> payload,
  ) async {
    return send(
      '/attendance/mark',
      body: payload,
      method: 'POST',
    );
  }

  // GET /attendance/me
  // Current student's attendance history
  Future<APIResponse> fetchMyAttendance() async {
    return fetch('/attendance/me');
  }

  // GET /attendance/course/:courseId
  // Attendance roster for a course
  Future<APIResponse> fetchCourseAttendance(
    String courseId, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return fetch(
      '/attendance/course/$courseId',
      query: queryParameters,
    );
  }
}