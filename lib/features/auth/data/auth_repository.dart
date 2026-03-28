import 'package:hopefulme_flutter/core/network/api_client.dart';
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

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
  }) => _apiClient.put(path, body: body);

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
    required String gender,
    required String password,
  }) async {
    final response = await _apiClient.post(
      'auth/register',
      body: <String, dynamic>{
        'fullname': fullname,
        'username': username,
        'email': email,
        'gender': gender,
        'password': password,
        'password_confirmation': password,
        'device_name': 'app',
      },
    );

    return _persistAuthResponse(response);
  }

  Future<User> currentUser() async {
    final response = await _apiClient.get('auth/me');
    final userJson = response['user'] as Map<String, dynamic>? ?? response;
    return User.fromJson(userJson);
  }

  Future<void> pingPresence() async {
    await _apiClient.post('presence/ping');
  }

  Future<void> logout() async {
    try {
      await _apiClient.post('auth/logout');
    } finally {
      await _apiClient.clearToken();
    }
  }

  Future<bool> hasToken() async {
    final token = await _apiClient.tokenStorage.readToken();
    return token != null && token.isNotEmpty;
  }

  Future<User> _persistAuthResponse(Map<String, dynamic> response) async {
    final token =
        response['token']?.toString() ??
        response['access_token']?.toString() ??
        response['data']?['token']?.toString();

    if (token != null && token.isNotEmpty) {
      await _apiClient.saveToken(token);
    }

    final userJson =
        response['user'] as Map<String, dynamic>? ??
        response['data']?['user'] as Map<String, dynamic>? ??
        response['data'] as Map<String, dynamic>?;

    return User.fromJson(userJson ?? <String, dynamic>{});
  }
}
