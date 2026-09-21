import 'package:attendx/services/attendance_service.dart';
import 'package:attendx/shared/models/attendance_record.dart';
import 'package:flutter/material.dart';

class AttendanceController extends ChangeNotifier {
  List<AttendanceRecord> attendanceHistory = [];
  bool isLoading = false;
  String? errorMessage;
  final AttendanceService _service = AttendanceService();

  Future<void> fetchStudentAttendanceHistory() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final res = await _service.fetchMyAttendance();
      if (res.success) {
        final data = res.data['items'];
        if (data is List) {
          attendanceHistory = data
              .map(
                (attendance) => AttendanceRecord.fromJson(
                  attendance as Map<String, dynamic>,
                ),
              )
              .toList();
        } else {
          errorMessage = 'Invalid course data received from server.';
        }
      } else {
        errorMessage = res.message;
      }
    } catch (e) {
      errorMessage = 'Failed to load courses.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAttendance(
      Map<String, dynamic> payload, BuildContext context) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    final res = await _service.markAttendance(payload);
    if (res.success) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(res.message)));
      notifyListeners();
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(res.message)));
      notifyListeners();
    }
  }

  Future<List<AttendanceRecord>> getAttendanceForCourse(String courseId) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    final res = await _service.fetchCourseAttendance(courseId);
    if (res.success) {
      final attendance = res.data['items'];
      if (attendance is List) {
        final attendanceData =
            attendance.map((c) => AttendanceRecord.fromJson(res.data)).toList();
        return attendanceData;
      }
    } else {
      return [];
    }
    return [];
  }
}
