import 'user.dart';

class Lecturer extends AppUser {
  final String staffId;
  final String title;

  const Lecturer({
    required super.id,
    required super.fullName,
    required super.email,
    required super.department,
    required super.faculty,
    super.avatarUrl,
    required this.staffId,
    this.title = 'Dr.',
    required super.accessToken,
  }) : super(role: UserRole.lecturer);

  factory Lecturer.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;

    return Lecturer(
      id: user['id'] as String,
      fullName: user['fullName'] as String,
      email: user['email'] as String,
      department: user['department'] as String,
      faculty: user['faculty'] as String,
      avatarUrl: user['avatarUrl'] as String?,
      staffId: user['staffId'] as String,
      title: user['title'] as String? ?? 'Dr.',
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
      'staffId': staffId,
      'title': title,
      'accessToken': accessToken,
    };
  }
}
