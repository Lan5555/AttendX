import 'user.dart';

class Student extends AppUser {
  final String studentId;
  final String semester;
  final double overallAttendancePercentage;

  const Student({
    required super.id,
    required super.fullName,
    required super.email,
    required super.department,
    required super.faculty,
    super.avatarUrl,
    required this.studentId,
    required this.semester,
    required this.overallAttendancePercentage,
  }) : super(role: UserRole.student);
}
