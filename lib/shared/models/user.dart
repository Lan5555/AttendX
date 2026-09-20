enum UserRole { student, lecturer }

/// Base user model. [Student] and [Lecturer] extend the shared fields
/// a real backend user record would carry.
class AppUser {
  final String id;
  final String fullName;
  final String email;
  final UserRole role;
  final String department;
  final String faculty;
  final String? avatarUrl;

  const AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.department,
    required this.faculty,
    this.avatarUrl,
  });
}
