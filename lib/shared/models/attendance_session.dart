enum SessionStatus { upcoming, active, paused, completed }

class AttendanceSession {
  final String id;
  final String courseId;
  final String courseCode;
  final String courseTitle;
  final String timeRangeLabel;
  final String venue;
  final int totalStudents;
  final int presentCount;
  final SessionStatus status;
  final String qrPayload; // mock rotating payload
  final DateTime? startedAt;
  final DateTime? endedAt;

  const AttendanceSession({
    required this.id,
    required this.courseId,
    required this.courseCode,
    required this.courseTitle,
    required this.timeRangeLabel,
    required this.venue,
    required this.totalStudents,
    this.presentCount = 0,
    this.status = SessionStatus.upcoming,
    this.qrPayload = '',
    this.startedAt,
    this.endedAt,
  });

  double get attendanceRate =>
      totalStudents == 0 ? 0 : (presentCount / totalStudents) * 100;

  AttendanceSession copyWith({
    int? presentCount,
    SessionStatus? status,
    String? qrPayload,
    DateTime? startedAt,
    DateTime? endedAt,
  }) {
    return AttendanceSession(
      id: id,
      courseId: courseId,
      courseCode: courseCode,
      courseTitle: courseTitle,
      timeRangeLabel: timeRangeLabel,
      venue: venue,
      totalStudents: totalStudents,
      presentCount: presentCount ?? this.presentCount,
      status: status ?? this.status,
      qrPayload: qrPayload ?? this.qrPayload,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
    );
  }
}
