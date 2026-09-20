import '../models/attendance_record.dart';

/// Abstract attendance-history/records contract.
abstract class AttendanceService {
  Future<List<AttendanceRecord>> getStudentHistory({String? courseId});
  Future<List<AttendanceRecord>> getCourseRecords(String courseId);
  Future<AttendanceRecord> recordAttendance({
    required String courseId,
    required String courseCode,
    required String courseTitle,
    required bool isOnline,
  });
}
