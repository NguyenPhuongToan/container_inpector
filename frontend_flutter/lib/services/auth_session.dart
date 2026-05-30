import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';

class AuthSession {
  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  static String? _token;
  static AppUser? _user;

  static String? get token => _token;
  static AppUser? get user => _user;
  static bool get isLoggedIn => _token != null && _user != null;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);

    final userJson = prefs.getString(_userKey);
    if (userJson == null) {
      _user = null;
      return;
    }

    try {
      _user = AppUser.fromJson(jsonDecode(userJson));
    } catch (_) {
      await clear();
    }
  }

  static Future<void> save({
    required String token,
    required AppUser user,
  }) async {
    _token = token;
    _user = user;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  static Future<void> clear() async {
    _token = null;
    _user = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }
}
