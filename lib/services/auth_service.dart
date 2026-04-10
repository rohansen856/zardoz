import 'package:flutter/material.dart';
import '../models/user.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  User? _currentUser;
  bool _isLoading = false;

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoading => _isLoading;

  Future<void> login(String name, String username) async {
    _isLoading = true;
    notifyListeners();
    try {
      _currentUser = await ApiService().login(name, username);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void logout() {
    _currentUser = null;
    ApiService().setUserId(null);
    notifyListeners();
  }
}
