import '../models/attendance_record.dart';
import '../mock/mock_data.dart';
import 'attendance_service.dart';

class MockAttendanceService implements AttendanceService {
  final List<AttendanceRecord> _created = [];

  @override
  Future<List<AttendanceRecord>> getStudentHistory({String? courseId}) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final base = MockData.fullStudentHistory();
    return [..._created, ...base];
  }

  @override
  Future<List<AttendanceRecord>> getCourseRecords(String courseId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final course = MockData.studentCourses.firstWhere(
      (c) => c.id == courseId,
      orElse: () => MockData.studentCourses.first,
    );
    return MockData.studentHistory(course.code, course.title);
  }

  @override
  Future<AttendanceRecord> recordAttendance({
    required String courseId,
    required String courseCode,
    required String courseTitle,
    required bool isOnline,
  }) async {
    await Future.delayed(const Duration(milliseconds: 900));
    final now = DateTime.now();
    final record = AttendanceRecord(
      id: 'r_${now.millisecondsSinceEpoch}',
      courseCode: courseCode,
      courseTitle: courseTitle,
      date: now,
      time: _formatTime(now),
      verification: RecordVerification.verified,
      syncStatus: isOnline ? SyncStatus.synced : SyncStatus.savedOffline,
    );
    _created.insert(0, record);
    return record;
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
