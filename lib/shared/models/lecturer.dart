import 'user.dart';

class Lecturer extends AppUser {
  final String staffId;
  final String title; // e.g. "Dr.", "Prof.", "Mr."

  const Lecturer({
    required super.id,
    required super.fullName,
    required super.email,
    required super.department,
    required super.faculty,
    super.avatarUrl,
    required this.staffId,
    this.title = 'Dr.',
  }) : super(role: UserRole.lecturer);
}
