import 'package:attendx/services/auth_service.dart';
import 'package:attendx/shared/models/user.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AuthController extends ChangeNotifier {
  AppUser? currentUser;
  bool isOnline = true;

  Future<void> logout() async {}

  void setCurrentUser(AppUser user) {
    currentUser = user;
    notifyListeners();
  }

  Future<void> restoreSession(BuildContext context) async {
    final res = await AuthService.instance.pingServer();
    if (res.success) {
     context.go('/login');
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(res.message)));
    }
  }
}
