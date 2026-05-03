import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  static const _kUser = 'current_user';

  User? _currentUser;
  bool _isLoading = false;
  bool _initialized = false;

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoading => _isLoading;
  bool get initialized => _initialized;

  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kUser);
    if (raw != null) {
      try {
        _currentUser = User.fromJson(jsonDecode(raw));
        ApiService().setUserId(_currentUser!.id);
      } catch (_) {
        await prefs.remove(_kUser);
      }
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> login(String name, String username) async {
    _isLoading = true;
    notifyListeners();
    try {
      _currentUser = await ApiService().login(name, username);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kUser, jsonEncode(_currentUser!.toJson()));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    ApiService().setUserId(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUser);
    notifyListeners();
  }
}
