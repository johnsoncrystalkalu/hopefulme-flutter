import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:hopefulme_flutter/features/auth/models/user.dart';

class TokenStorage {
  static const _tokenKey = 'auth_token';
  static const _cachedUserKey = 'cached_auth_user';
  static const _impersonationTokenKey = 'impersonation_admin_token';
  static const _impersonationUserKey = 'impersonation_admin_user';

  Future<String?> readToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Future<void> saveImpersonationBackup({
    required String adminToken,
    required User adminUser,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_impersonationTokenKey, adminToken);
    await prefs.setString(_impersonationUserKey, jsonEncode(adminUser.toJson()));
  }

  Future<String?> readImpersonationToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_impersonationTokenKey);
  }

  Future<User?> readImpersonationUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_impersonationUserKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return User.fromJson(decoded);
      }
    } catch (_) {}

    return null;
  }

  Future<bool> hasImpersonationBackup() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_impersonationTokenKey);
    return token != null && token.isNotEmpty;
  }

  Future<void> clearImpersonationBackup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_impersonationTokenKey);
    await prefs.remove(_impersonationUserKey);
  }

  Future<void> saveCachedUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cachedUserKey, jsonEncode(user.toJson()));
  }

  Future<User?> readCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cachedUserKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return User.fromJson(decoded);
      }
    } catch (_) {}

    return null;
  }

  Future<void> clearCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cachedUserKey);
  }
}
