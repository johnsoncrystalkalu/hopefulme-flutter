import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:hopefulme_flutter/core/config/app_config.dart';
import 'package:hopefulme_flutter/core/network/api_exception.dart';
import 'package:hopefulme_flutter/core/storage/token_storage.dart';

class ApiClient {
  ApiClient({
    required this.baseUrl,
    required this.tokenStorage,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final TokenStorage tokenStorage;
  final http.Client _httpClient;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) => _sendJsonRequest(
    () async => _httpClient
        .get(
          await _buildUri(path, queryParameters: queryParameters),
          headers: await _headers(),
        )
        .timeout(AppConfig.requestTimeout),
  );

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) => _sendJsonRequest(
    () async => _httpClient
        .post(
          await _buildUri(path),
          headers: await _headers(),
          body: jsonEncode(body ?? <String, dynamic>{}),
        )
        .timeout(AppConfig.requestTimeout),
  );

  Future<Map<String, dynamic>> postMultipart(
    String path, {
    Map<String, String>? fields,
    List<ApiMultipartFile> files = const <ApiMultipartFile>[],
  }) => _sendJsonRequest(() async {
    final request = http.MultipartRequest('POST', await _buildUri(path));
    request.headers.addAll(await _multipartHeaders());
    if (fields != null && fields.isNotEmpty) {
      request.fields.addAll(fields);
    }
    for (final file in files) {
      request.files.add(
        http.MultipartFile.fromBytes(
          file.field,
          file.bytes,
          filename: file.filename,
        ),
      );
    }

    final streamed = await request.send().timeout(AppConfig.requestTimeout);
    return http.Response.fromStream(streamed);
  });

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
  }) => _sendJsonRequest(
    () async => _httpClient
        .patch(
          await _buildUri(path),
          headers: await _headers(),
          body: jsonEncode(body ?? <String, dynamic>{}),
        )
        .timeout(AppConfig.requestTimeout),
  );

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
  }) => _sendJsonRequest(
    () async => _httpClient
        .put(
          await _buildUri(path),
          headers: await _headers(),
          body: jsonEncode(body ?? <String, dynamic>{}),
        )
        .timeout(AppConfig.requestTimeout),
  );

  Future<Map<String, dynamic>> delete(String path) => _sendJsonRequest(
    () async => _httpClient
        .delete(
          await _buildUri(path),
          headers: await _headers(),
        )
        .timeout(AppConfig.requestTimeout),
  );

  Future<void> saveToken(String token) => tokenStorage.saveToken(token);

  Future<void> clearToken() => tokenStorage.clearToken();

  Future<Uri> _buildUri(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final normalizedBase = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    final uri = Uri.parse('$normalizedBase$normalizedPath');
    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }

    return uri.replace(
      queryParameters: queryParameters.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
    );
  }

  Future<Map<String, String>> _headers() async {
    final token = await tokenStorage.readToken();

    return <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Client-Platform': 'app',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, String>> _multipartHeaders() async {
    final token = await tokenStorage.readToken();

    return <String, String>{
      'Accept': 'application/json',
      'X-Client-Platform': 'app',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> _sendJsonRequest(
    Future<http.Response> Function() request,
  ) async {
    try {
      final response = await request();
      return _decodeResponse(response);
    } on TimeoutException {
      throw ApiException(_transportErrorMessage('The server took too long to respond.'));
    } on http.ClientException catch (error) {
      throw ApiException(_transportErrorMessage(error.message));
    } on FormatException {
      throw ApiException('The server response could not be read. Please check the API response format.');
    } catch (error) {
      throw ApiException(_transportErrorMessage(error.toString()));
    }
  }

  String _transportErrorMessage(String details) {
    final base = details.trim().isEmpty
        ? 'Could not reach the server.'
        : 'Could not reach the server: $details';

    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        baseUrl.contains('10.0.2.2')) {
      return '$base Android emulator address `10.0.2.2` only works in the emulator. '
          'For a real phone, run with `--dart-define=API_BASE_URL=http://YOUR_COMPUTER_IP:8000/api`.';
    }

    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        baseUrl.startsWith('http://')) {
      return '$base Android is using a cleartext HTTP API at $baseUrl. '
          'Make sure the phone can reach that address on your Wi-Fi network.';
    }

    return base;
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final rawBody = _readResponseBody(response);
    final hasBody = rawBody.trim().isNotEmpty;
    final dynamic decoded = hasBody
        ? jsonDecode(rawBody)
        : <String, dynamic>{};
    final data = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{'data': decoded};

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    String? validationMessage;
    final errors = data['errors'];
    if (errors is Map<String, dynamic>) {
      for (final value in errors.values) {
        if (value is List && value.isNotEmpty) {
          validationMessage = value.first.toString();
          break;
        }
      }
    }

    final message =
        validationMessage ??
        data['message']?.toString() ??
        data['error']?.toString() ??
        'Request failed';
    throw ApiException(message, statusCode: response.statusCode);
  }

  String _readResponseBody(http.Response response) {
    if (response.bodyBytes.isEmpty) {
      return response.body;
    }

    try {
      return utf8.decode(response.bodyBytes);
    } on FormatException {
      return latin1.decode(response.bodyBytes, allowInvalid: true);
    }
  }
}

class ApiMultipartFile {
  const ApiMultipartFile({
    required this.field,
    required this.filename,
    required this.bytes,
  });

  final String field;
  final String filename;
  final Uint8List bytes;
}
