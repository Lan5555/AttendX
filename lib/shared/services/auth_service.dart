import '../models/user.dart';

class AuthResult {
  final bool success;
  final AppUser? user;
  final String? errorMessage;
  const AuthResult.success(this.user) : success = true, errorMessage = null;
  const AuthResult.failure(this.errorMessage) : success = false, user = null;
}

/// Abstract auth contract. A REST/Firebase/etc implementation can replace
/// [MockAuthService] later without touching any UI code.
abstract class AuthService {
  Future<AuthResult> login({required String identifier, required String password});

  Future<AuthResult> registerStudent({
    required String fullName,
    required String studentId,
    required String email,
    required String password,
    required String department,
    required String faculty,
  });

  Future<AuthResult> registerLecturer({
    required String fullName,
    required String staffId,
    required String email,
    required String password,
    required String department,
    required String faculty,
  });

  Future<void> logout();

  AppUser? get currentUser;
}
