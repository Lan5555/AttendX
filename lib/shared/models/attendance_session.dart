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
  final String qrPayload;
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

  factory AttendanceSession.fromJson(Map<String, dynamic> json) {
    return AttendanceSession(
      // /sessions/today returns id: null for upcoming sessions.
      id: json['id'] as String? ?? '',
      courseId: json['courseId'] as String? ?? '',
      courseCode: json['courseCode'] as String? ?? '',
      courseTitle: json['courseTitle'] as String? ?? '',
      timeRangeLabel: json['timeRangeLabel'] as String? ?? '',
      venue: json['venue'] as String? ?? '',
      totalStudents: json['totalStudents'] as int? ?? 0,
      presentCount: json['presentCount'] as int? ?? 0,
      status: _statusFromString(json['status'] as String?),
      qrPayload: json['qrPayload'] as String? ?? '',
      startedAt: _parseDate(json['startedAt']),
      endedAt: _parseDate(json['endedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'courseId': courseId,
        'courseCode': courseCode,
        'courseTitle': courseTitle,
        'timeRangeLabel': timeRangeLabel,
        'venue': venue,
        'totalStudents': totalStudents,
        'presentCount': presentCount,
        'status': status.name,
        'qrPayload': qrPayload,
        'startedAt': startedAt?.toIso8601String(),
        'endedAt': endedAt?.toIso8601String(),
      };

  double get attendanceRate =>
      totalStudents == 0 ? 0 : (presentCount / totalStudents) * 100;

  AttendanceSession copyWith({
    String? id,
    String? courseId,
    String? courseCode,
    String? courseTitle,
    String? timeRangeLabel,
    String? venue,
    int? totalStudents,
    int? presentCount,
    SessionStatus? status,
    String? qrPayload,
    DateTime? startedAt,
    DateTime? endedAt,
  }) {
    return AttendanceSession(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      courseCode: courseCode ?? this.courseCode,
      courseTitle: courseTitle ?? this.courseTitle,
      timeRangeLabel: timeRangeLabel ?? this.timeRangeLabel,
      venue: venue ?? this.venue,
      totalStudents: totalStudents ?? this.totalStudents,
      presentCount: presentCount ?? this.presentCount,
      status: status ?? this.status,
      qrPayload: qrPayload ?? this.qrPayload,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
    );
  }

  static SessionStatus _statusFromString(String? value) {
    // Backend uses UPPERCASE enum values: ACTIVE, PAUSED, COMPLETED, UPCOMING.
    if (value == null) return SessionStatus.upcoming;
    final normalized = value.toLowerCase();
    return SessionStatus.values.firstWhere(
      (e) => e.name == normalized,
      orElse: () => SessionStatus.upcoming,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}