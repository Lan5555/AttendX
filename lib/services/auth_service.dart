import 'package:attendx/core/network/core_service.dart';

class AuthService extends CoreService {
  AuthService._();

  static final AuthService instance = AuthService._();
  Future<APIResponse> loginUser(String identifier, String password) async {
    final payload = {"identifier": identifier, "password": password};
    return await send('/auth/login', body: payload);
  }

  Future<APIResponse> registerStudent(Map<String, dynamic> payload) async {
    return await send('/auth/register/student', body: payload);
  }

  Future<APIResponse> registerLecturer(Map<String, dynamic> payload) async {
    return await send('/auth/register/lecturer', body: payload);
  }
}
