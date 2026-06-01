import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/app_user.dart';

class AuthSession {
  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';
  static const _storage = FlutterSecureStorage();

  static String? _token;
  static AppUser? _user;

  static String? get token => _token;
  static AppUser? get user => _user;
  static bool get isLoggedIn => _token != null && _user != null;

  static Future<void> load() async {
    _token = await _storage.read(key: _tokenKey);

    final userJson = await _storage.read(key: _userKey);
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

    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userKey, value: jsonEncode(user.toJson()));
  }

  static Future<void> clear() async {
    _token = null;
    _user = null;

    await _storage.deleteAll();
  }
}
