import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../storage/secure_store.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient(this._store);

  final SecureStore _store;
  final http.Client _client = http.Client();

  Uri _buildUri(String path) {
    final base = AppConfig.apiBaseUrl.replaceAll(RegExp(r'/+$'), '');
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$cleanPath');
  }

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = false,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    if (auth) {
      final token = await _store.getAccessToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    final response = await _client.post(
      _buildUri(path),
      headers: headers,
      body: body == null ? null : jsonEncode(body),
    );

    return _decodeResponse(response);
  }

  Future<dynamic> put(
    String path, {
    Map<String, dynamic>? body,
    bool auth = false,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    if (auth) {
      final token = await _store.getAccessToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    final response = await _client.put(
      _buildUri(path),
      headers: headers,
      body: body == null ? null : jsonEncode(body),
    );

    return _decodeResponse(response);
  }

  Future<dynamic> delete(
    String path, {
    Map<String, dynamic>? body,
    bool auth = false,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    if (auth) {
      final token = await _store.getAccessToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    final response = await _client.delete(
      _buildUri(path),
      headers: headers,
      body: body == null ? null : jsonEncode(body),
    );

    return _decodeResponse(response);
  }

  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool auth = false,
  }) async {
    final headers = <String, String>{};

    if (auth) {
      final token = await _store.getAccessToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    final uri = _buildUri(path).replace(queryParameters: query);

    final response = await _client.get(uri, headers: headers);
    return _decodeResponse(response);
  }

  dynamic _decodeResponse(http.Response response) {
    if (response.body.isEmpty) {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return <String, dynamic>{};
      }
      throw ApiException(response.statusCode, 'Request failed');
    }

    final dynamic decoded = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final Map<String, dynamic> data =
          decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
      final message = data['message']?.toString() ?? 'Request failed';
      throw ApiException(response.statusCode, message);
    }

    return decoded;
  }
}
