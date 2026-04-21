import 'package:hopefulme_flutter/core/network/api_client.dart';
import 'package:hopefulme_flutter/core/network/api_exception.dart';
import 'package:hopefulme_flutter/features/auth/models/user.dart';

class AuthRepository {
  AuthRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) => _apiClient.get(path, queryParameters: queryParameters);

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) => _apiClient.post(path, body: body);

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
  }) => _apiClient.patch(path, body: body);

  Future<Map<String, dynamic>> postMultipart(
    String path, {
    Map<String, String>? fields,
    List<ApiMultipartFile> files = const <ApiMultipartFile>[],
  }) => _apiClient.postMultipart(path, fields: fields, files: files);

  Future<Map<String, dynamic>> putMultipart(
    String path, {
    Map<String, String>? fields,
    List<ApiMultipartFile> files = const <ApiMultipartFile>[],
  }) => _apiClient.putMultipart(path, fields: fields, files: files);

  Future<Map<String, dynamic>> put(String path, {Map<String, dynamic>? body}) =>
      _apiClient.put(path, body: body);

  Future<Map<String, dynamic>> delete(String path) => _apiClient.delete(path);

  Future<User> login({required String login, required String password}) async {
    final response = await _apiClient.post(
      'auth/login',
      body: <String, dynamic>{
        'login': login,
        'password': password,
        'device_name': 'app',
      },
    );

    return _persistAuthResponse(response);
  }

  Future<User> register({
    required String fullname,
    required String username,
    required String email,
    required String role1,
    required String gender,
    required String password,
  }) async {
    final response = await _apiClient.post(
      'auth/register',
      body: <String, dynamic>{
        'fullname': fullname,
        'username': username,
        'email': email,
        'role1': role1,
        'gender': gender,
        'password': password,
        'password_confirmation': password,
        'device_name': 'app',
      },
    );

    return _persistAuthResponse(response);
  }

  Future<String> requestPasswordReset({required String email}) async {
    final response = await _apiClient.post(
      'auth/forgot-password',
      body: <String, dynamic>{
        'email': email.trim(),
      },
    );

    return response['message']?.toString() ??
        'We have emailed your password reset link.';
  }

  Future<String> resetPassword({
    required String token,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    final response = await _apiClient.post(
      'auth/reset-password',
      body: <String, dynamic>{
        'token': token.trim(),
        'email': email.trim(),
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    );

    return response['message']?.toString() ?? 'Password reset successful.';
  }

  Future<bool> checkUsernameAvailability(String username) async {
    final normalized = username.trim().replaceFirst('@', '');
    final response = await _apiClient.get(
      'auth/check-username',
      queryParameters: <String, dynamic>{'username': normalized},
    );
    return response['available'] == true;
  }

  Future<List<String>> fetchRegistrationRoles() async {
    final response = await _apiClient.get('auth/register-options');
    return (response['roles'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();
  }

  Future<User> currentUser() async {
    final response = await _apiClient.get('auth/me');
    final userJson = response['user'] as Map<String, dynamic>? ?? response;
    final user = User.fromJson(userJson);
    await _apiClient.tokenStorage.saveCachedUser(user);
    return user;
  }

  Future<void> pingPresence() async {
    await _apiClient.post('presence/ping');
  }

  Future<String> createWebSessionUrl(String target) async {
    final response = await _apiClient.post(
      'auth/web-session-link',
      body: <String, dynamic>{'target': target},
    );

    return response['url']?.toString() ?? '';
  }

  Future<void> logout() async {
    try {
      await _apiClient.post('auth/logout');
    } finally {
      await _apiClient.clearToken();
      await _apiClient.tokenStorage.clearCachedUser();
      await _apiClient.tokenStorage.clearImpersonationBackup();
    }
  }

  Future<User> loginAsUser({required String username}) async {
    final normalized = username.trim().replaceFirst('@', '');
    final currentToken = await _apiClient.tokenStorage.readToken();
    final currentUser = await _apiClient.tokenStorage.readCachedUser();
    if (currentToken != null &&
        currentToken.isNotEmpty &&
        currentUser != null &&
        currentUser.isAdmin) {
      await _apiClient.tokenStorage.saveImpersonationBackup(
        adminToken: currentToken,
        adminUser: currentUser,
      );
    }

    final response = await _apiClient.post(
      'auth/login-as/$normalized',
      body: const <String, dynamic>{},
    );

    return _persistAuthResponse(response);
  }

  Future<bool> hasImpersonationBackup() =>
      _apiClient.tokenStorage.hasImpersonationBackup();

  Future<User> switchBackFromImpersonation() async {
    final adminToken = await _apiClient.tokenStorage.readImpersonationToken();
    final adminUser = await _apiClient.tokenStorage.readImpersonationUser();
    final activeToken = await _apiClient.tokenStorage.readToken();
    final activeUser = await _apiClient.tokenStorage.readCachedUser();

    if (adminToken == null ||
        adminToken.isEmpty ||
        adminUser == null ||
        !adminUser.isAdmin) {
      throw ApiException('Admin backup session is unavailable.');
    }

    await _apiClient.saveToken(adminToken);
    await _apiClient.tokenStorage.saveCachedUser(adminUser);

    try {
      final refreshed = await currentUser();
      await _apiClient.tokenStorage.clearImpersonationBackup();
      return refreshed;
    } on ApiException {
      if (activeToken != null && activeToken.isNotEmpty) {
        await _apiClient.saveToken(activeToken);
      }
      if (activeUser != null) {
        await _apiClient.tokenStorage.saveCachedUser(activeUser);
      }
      rethrow;
    }
  }

  Future<void> registerOneSignalPlayerId(String playerId) async {
    await _apiClient.post(
      'auth/onesignal-player-id',
      body: <String, dynamic>{'onesignal_player_id': playerId},
    );
  }

  Future<bool> hasToken() async {
    final token = await _apiClient.tokenStorage.readToken();
    return token != null && token.isNotEmpty;
  }

  Future<User?> readCachedUser() => _apiClient.tokenStorage.readCachedUser();

  Future<void> clearLocalSession() async {
    await _apiClient.clearToken();
    await _apiClient.tokenStorage.clearCachedUser();
    await _apiClient.tokenStorage.clearImpersonationBackup();
  }

  Future<User> _persistAuthResponse(Map<String, dynamic> response) async {
    String? token;
    token ??= response['token']?.toString();
    token ??= response['access_token']?.toString();
    token ??= response['data']?['token']?.toString();
    token ??= response['data']?['access_token']?.toString();
    token ??= (response['data'] is Map)
        ? (response['data'] as Map)['token']?.toString()
        : null;
    token ??= (response['data'] is Map)
        ? (response['data'] as Map)['access_token']?.toString()
        : null;

    if (token != null && token.isNotEmpty) {
      await _apiClient.saveToken(token);
    }

    Map<String, dynamic>? userJson;
    userJson ??= response['user'] as Map<String, dynamic>?;
    userJson ??= response['data']?['user'] as Map<String, dynamic>?;
    if (response['data'] is Map<String, dynamic>) {
      userJson ??= response['data'] as Map<String, dynamic>;
    }

    final user = User.fromJson(userJson ?? <String, dynamic>{});
    await _apiClient.tokenStorage.saveCachedUser(user);
    return user;
  }
}
