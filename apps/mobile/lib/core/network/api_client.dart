import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../device/device_id.dart';
import '../storage/secure_store.dart';
import 'api_exception.dart';

/// Enhanced API client with automatic JWT token refresh.
/// When a request returns 401, the client attempts a single token refresh
/// using the stored refresh token. If the refresh succeeds, the original
/// request is retried with the new access token. If the refresh also fails,
/// the [onForceLogout] callback is invoked to clear the session.
class ApiClient {
  ApiClient(this._store, {this.onForceLogout});

  final SecureStore _store;

  /// Called when token refresh fails (session expired / revoked).
  /// The caller should clear auth state and redirect to login.
  final Future<void> Function()? onForceLogout;

  final http.Client _client = http.Client();

  /// In-flight refresh future to deduplicate concurrent refresh calls.
  Future<bool>? _refreshLock;

  Uri _buildUri(String path) {
    final base = AppConfig.apiBaseUrl.replaceAll(RegExp(r'/+$'), '');
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$cleanPath');
  }

  Future<Map<String, String>> _headers({bool auth = false}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final token = await _store.getAccessToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = false,
  }) async {
    return _requestWithRetry('POST', path, body: body, auth: auth);
  }

  Future<dynamic> put(
    String path, {
    Map<String, dynamic>? body,
    bool auth = false,
  }) async {
    return _requestWithRetry('PUT', path, body: body, auth: auth);
  }

  Future<dynamic> patch(
    String path, {
    Map<String, dynamic>? body,
    bool auth = false,
  }) async {
    return _requestWithRetry('PATCH', path, body: body, auth: auth);
  }

  Future<dynamic> delete(
    String path, {
    Map<String, dynamic>? body,
    bool auth = false,
  }) async {
    return _requestWithRetry('DELETE', path, body: body, auth: auth);
  }

  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool auth = false,
  }) async {
    final headers = await _headers(auth: auth);
    final uri = _buildUri(path).replace(queryParameters: query);

    final response = await _client.get(uri, headers: headers);

    if (response.statusCode == 401 && auth) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        final retryHeaders = await _headers(auth: true);
        final retryResponse =
            await _client.get(uri, headers: retryHeaders);
        return _decodeResponse(retryResponse);
      }
      await _handleForceLogout();
    }

    return _decodeResponse(response);
  }

  /// Core method: sends the request, and if 401 + auth, attempts refresh + retry.
  Future<dynamic> _requestWithRetry(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool auth = false,
  }) async {
    final headers = await _headers(auth: auth);
    final uri = _buildUri(path);
    final encodedBody = body == null ? null : jsonEncode(body);

    final response = await _send(method, uri, headers, encodedBody);

    // If unauthorized on an authenticated request, try refreshing
    if (response.statusCode == 401 && auth) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        final retryHeaders = await _headers(auth: true);
        final retryResponse =
            await _send(method, uri, retryHeaders, encodedBody);
        return _decodeResponse(retryResponse);
      }
      await _handleForceLogout();
    }

    return _decodeResponse(response);
  }

  Future<http.Response> _send(
    String method,
    Uri uri,
    Map<String, String> headers,
    String? body,
  ) async {
    switch (method) {
      case 'POST':
        return _client.post(uri, headers: headers, body: body);
      case 'PUT':
        return _client.put(uri, headers: headers, body: body);
      case 'PATCH':
        return _client.patch(uri, headers: headers, body: body);
      case 'DELETE':
        return _client.delete(uri, headers: headers, body: body);
      default:
        return _client.get(uri, headers: headers);
    }
  }

  /// Attempt to refresh the access token using the stored refresh token.
  /// Returns true if refresh succeeded, false otherwise.
  /// Uses [_refreshLock] to prevent concurrent refresh requests.
  Future<bool> _tryRefresh() {
    _refreshLock ??= _doRefresh().whenComplete(() => _refreshLock = null);
    return _refreshLock!;
  }

  Future<bool> _doRefresh() async {
    try {
      final refreshToken = await _store.getRefreshToken();
      final deviceId = await DeviceIdStore(_store).getOrCreate();

      if (refreshToken == null || refreshToken.isEmpty) {
        return false;
      }

      final response = await _client.post(
        _buildUri('/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'refreshToken': refreshToken,
          'deviceId': deviceId,
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return false;

      final newAccessToken = data['accessToken']?.toString() ?? '';
      final newRefreshToken = data['refreshToken']?.toString() ?? '';

      if (newAccessToken.isEmpty) return false;

      await _store.setAccessToken(newAccessToken);
      if (newRefreshToken.isNotEmpty) {
        await _store.setRefreshToken(newRefreshToken);
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _handleForceLogout() async {
    if (onForceLogout != null) {
      await onForceLogout!();
    }
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
      final Map<String, dynamic> data = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{};
      final message = data['message']?.toString() ?? 'Request failed';
      throw ApiException(response.statusCode, message);
    }

    return decoded;
  }
}
