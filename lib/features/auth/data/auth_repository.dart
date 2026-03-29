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

    return User.fromJson(userJson ?? <String, dynamic>{});
  }
}
