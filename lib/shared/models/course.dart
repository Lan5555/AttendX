import 'course_schedule.dart';

enum AttendanceEligibility {
  eligible,
  atRisk,
  ineligible,
}

class Course {
  final String id;
  final String code;
  final String title;
  final String description;
  final String lecturerName;
  final int creditUnits;
  final String department;
  final CourseSchedule schedule;
  final int maxStudents;
  final int enrolledStudents;
  final int classesHeld;
  final int classesAttended;
  final double attendanceThreshold;

  const Course({
    required this.id,
    required this.code,
    required this.title,
    this.description = '',
    required this.lecturerName,
    required this.creditUnits,
    required this.department,
    required this.schedule,
    this.maxStudents = 120,
    this.enrolledStudents = 0,
    required this.classesHeld,
    required this.classesAttended,
    this.attendanceThreshold = 75.0,
  });

 factory Course.fromJson(Map<String, dynamic> json) {
  // Guard the lecturer — it may be missing or null.
  final lecturerRaw = json['lecturer'];
  final lecturer =
      lecturerRaw is Map<String, dynamic> ? lecturerRaw : null;

  return Course(
    id: json['id']?.toString() ?? '',
    code: json['code']?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    description: json['description']?.toString() ?? '',
    lecturerName:
        lecturer?['fullName']?.toString() ?? 'Unknown Lecturer',
    creditUnits: (json['creditUnits'] as num?)?.toInt() ?? 0,
    department: json['department']?.toString() ?? '',
    schedule: CourseSchedule(
      day: json['scheduleDay']?.toString() ?? '',
      startTime: json['scheduleStartTime']?.toString() ?? '',
      endTime: json['scheduleEndTime']?.toString() ?? '',
      recurringWeekly: json['scheduleRecurringWeekly'] as bool? ?? true,
      venue: json['venue']?.toString() ?? 'TBA',
    ),
    maxStudents: (json['maxStudents'] as num?)?.toInt() ?? 120,
    enrolledStudents: (json['enrolledStudents'] as num?)?.toInt() ?? 0,
    classesHeld: (json['classesHeld'] as num?)?.toInt() ?? 0,
    classesAttended: (json['classesAttended'] as num?)?.toInt() ?? 0,
    attendanceThreshold:
        (json['attendanceThreshold'] as num?)?.toDouble() ?? 75.0,
  );
}

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'title': title,
        'description': description,
        'lecturerName': lecturerName,
        'creditUnits': creditUnits,
        'department': department,
        'schedule': schedule.toJson(),
        'maxStudents': maxStudents,
        'enrolledStudents': enrolledStudents,
        'classesHeld': classesHeld,
        'classesAttended': classesAttended,
        'attendanceThreshold': attendanceThreshold,
      };

  /// Classes the student did not attend. Never negative — a mismatch
  /// between `classesAttended` and `classesHeld` (e.g. the enrollment
  /// counter hasn't caught up with the attendance record yet) should
  /// not surface to the UI as a negative number.
  int get classesMissed {
    final missed = classesHeld - classesAttended;
    return missed < 0 ? 0 : missed;
  }

  double get attendancePercentage {
    if (classesHeld == 0) return 0;
    return (classesAttended / classesHeld) * 100;
  }

  AttendanceEligibility get eligibility {
    // No sessions held yet — nothing to evaluate. Treat as on track so
    // brand-new courses don't get flagged as "at risk".
    if (classesHeld == 0) return AttendanceEligibility.eligible;

    final pct = attendancePercentage;
    if (pct >= attendanceThreshold) return AttendanceEligibility.eligible;
    if (pct >= attendanceThreshold - 15) return AttendanceEligibility.atRisk;
    return AttendanceEligibility.ineligible;
  }

  Map<String, dynamic> toAdvancedJson() => {
        'code': code,
        'title': title,
        'description': description,
        'creditUnits': creditUnits,
        'department': department,
        'scheduleDay': schedule.day,
        'scheduleStartTime': schedule.startTime,
        'scheduleEndTime': schedule.endTime,
        'scheduleRecurringWeekly': schedule.recurringWeekly,
        'venue': schedule.venue,
        'maxStudents': maxStudents,
        'attendanceThreshold': attendanceThreshold,
      };
}