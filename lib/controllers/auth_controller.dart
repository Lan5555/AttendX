import 'package:attendx/shared/models/user.dart';
import 'package:flutter/material.dart';

class AuthController extends ChangeNotifier {
  AppUser? currentUser;
  bool isOnline = true;

  Future<void> logout () async {

  }

void setCurrentUser(AppUser user) {
  currentUser = user;
  notifyListeners();
}

}
