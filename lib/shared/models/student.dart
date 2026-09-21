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
    required super.accessToken,
  }) : super(role: UserRole.student);

  factory Student.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;

    return Student(
      id: user['id'] as String,
      fullName: user['fullName'] as String,
      email: user['email'] as String,
      department: user['department'] as String,
      faculty: user['faculty'] as String,
      avatarUrl: user['avatarUrl'] as String?,
      studentId: user['studentId'] as String,
      semester: user['semester'] as String,
      overallAttendancePercentage:
          (user['overallAttendancePercentage'] as num).toDouble(),
      accessToken: json['accessToken'] as String,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'role': role.name,
      'department': department,
      'faculty': faculty,
      'avatarUrl': avatarUrl,
      'studentId': studentId,
      'semester': semester,
      'overallAttendancePercentage': overallAttendancePercentage,
      'accessToken': accessToken,
    };
  }
}
