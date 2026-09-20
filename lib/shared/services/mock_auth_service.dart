import '../models/user.dart';
import '../models/student.dart';
import '../models/lecturer.dart';
import '../mock/mock_data.dart';
import 'auth_service.dart';

/// Mock in-memory implementation of [AuthService]. Simulates network
/// latency and realistic failure cases so the UI can demonstrate its
/// loading / error states. Replace with a REST implementation later.
class MockAuthService implements AuthService {
  AppUser? _currentUser;

  @override
  AppUser? get currentUser => _currentUser;

  @override
  Future<AuthResult> login({required String identifier, required String password}) async {
    await Future.delayed(const Duration(milliseconds: 1100));

    if (password.length < 4) {
      return const AuthResult.failure('Incorrect email/ID or password.');
    }

    if (identifier.toLowerCase().contains('lec') ||
        identifier.toLowerCase().contains('staff') ||
        identifier.toLowerCase().contains('stf')) {
      _currentUser = MockData.demoLecturer;
    } else {
      _currentUser = MockData.demoStudent;
    }
    return AuthResult.success(_currentUser);
  }

  @override
  Future<AuthResult> registerStudent({
    required String fullName,
    required String studentId,
    required String email,
    required String password,
    required String department,
    required String faculty,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1200));
    final user = Student(
      id: 'u_new_stu',
      fullName: fullName,
      email: email,
      department: department,
      faculty: faculty,
      studentId: studentId,
      semester: 'Rain Semester, 2025/2026',
      overallAttendancePercentage: 0,
    );
    _currentUser = user;
    return AuthResult.success(user);
  }

  @override
  Future<AuthResult> registerLecturer({
    required String fullName,
    required String staffId,
    required String email,
    required String password,
    required String department,
    required String faculty,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1200));
    final user = Lecturer(
      id: 'u_new_lec',
      fullName: fullName,
      email: email,
      department: department,
      faculty: faculty,
      staffId: staffId,
    );
    _currentUser = user;
    return AuthResult.success(user);
  }

  @override
  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 400));
    _currentUser = null;
  }
}
