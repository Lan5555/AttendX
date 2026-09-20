import 'course_schedule.dart';

enum AttendanceEligibility { eligible, atRisk, ineligible }

class Course {
  final String id;
  final String code; // e.g. CSC 416
  final String title; // e.g. Software Engineering
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

  int get classesMissed => classesHeld - classesAttended;

  double get attendancePercentage {
    if (classesHeld == 0) return 0;
    return (classesAttended / classesHeld) * 100;
  }

  AttendanceEligibility get eligibility {
    final pct = attendancePercentage;
    if (pct >= attendanceThreshold) return AttendanceEligibility.eligible;
    if (pct >= attendanceThreshold - 15) return AttendanceEligibility.atRisk;
    return AttendanceEligibility.ineligible;
  }
}
