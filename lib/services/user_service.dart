import 'package:attendx/core/network/core_service.dart';

class UserService extends CoreService {
  Future<APIResponse> fetchUser() async {
    return fetch('/users/me');
  }

  Future<APIResponse> updateUser(Map<String, dynamic> payload) async {
    return send('/users/me', body: payload, method: 'PATCH');
  }
}
