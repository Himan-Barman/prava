import '../core/device/device_id.dart';
import '../core/network/api_client.dart';
import '../core/storage/secure_store.dart';

class AuthSession {
  AuthSession({
    required this.userId,
    required this.email,
    required this.accessToken,
    required this.refreshToken,
    required this.isVerified,
  });

  final String userId;
  final String email;
  final String accessToken;
  final String refreshToken;
  final bool isVerified;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? {};
    return AuthSession(
      userId: user['id']?.toString() ?? '',
      email: user['email']?.toString() ?? '',
      accessToken: json['accessToken']?.toString() ?? '',
      refreshToken: json['refreshToken']?.toString() ?? '',
      isVerified: user['isVerified'] == true,
    );
  }
}

class AuthService {
  factory AuthService({SecureStore? store}) {
    final resolved = store ?? SecureStore();
    return AuthService._(
      resolved,
      DeviceIdStore(resolved),
      ApiClient(resolved),
    );
  }

  AuthService._(this._store, this._deviceIdStore, this._client);

  final SecureStore _store;
  final DeviceIdStore _deviceIdStore;
  final ApiClient _client;

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final deviceId = await _deviceIdStore.getOrCreate();
    final data = await _client.post('/auth/login', body: {
      'email': email,
      'password': password,
      'deviceId': deviceId,
    });

    final session = AuthSession.fromJson(data);
    await _saveSession(session);
    return session;
  }

  Future<AuthSession> register({
    required String email,
    required String password,
    String? username,
  }) async {
    final deviceId = await _deviceIdStore.getOrCreate();
    final body = <String, dynamic>{
      'email': email,
      'password': password,
      'deviceId': deviceId,
    };
    if (username != null && username.isNotEmpty) {
      body['username'] = username;
    }

    final data = await _client.post('/auth/register', body: body);

    final session = AuthSession.fromJson(data);
    await _saveSession(session);
    return session;
  }

  Future<bool> isUsernameAvailable(String username) async {
    final data = await _client.get(
      '/users/username-available',
      query: {'username': username},
    );
    if (data is Map<String, dynamic>) {
      return data['available'] == true;
    }
    return false;
  }

  Future<void> requestPasswordReset({
    required String email,
  }) async {
    await _client.post('/auth/password-reset/request', body: {
      'email': email,
    });
  }

  Future<void> confirmPasswordReset({
    required String token,
    required String newPassword,
  }) async {
    await _client.post('/auth/password-reset/confirm', body: {
      'token': token,
      'newPassword': newPassword,
    });
  }

  Future<void> requestEmailOtp({
    required String email,
  }) async {
    await _client.post('/auth/email-otp/request', body: {
      'email': email,
    });
  }

  Future<void> verifyEmailOtp({
    required String email,
    required String code,
  }) async {
    await _client.post('/auth/email-otp/verify', body: {
      'email': email,
      'code': code,
    });
  }

  Future<void> updateUserDetails({
    required String firstName,
    required String lastName,
    required String phoneCountryCode,
    required String phoneNumber,
  }) async {
    await _client.put(
      '/users/me/details',
      body: {
        'firstName': firstName,
        'lastName': lastName,
        'phoneCountryCode': phoneCountryCode,
        'phoneNumber': phoneNumber,
      },
      auth: true,
    );
  }

  Future<void> _saveSession(AuthSession session) async {
    if (session.accessToken.isNotEmpty) {
      await _store.setAccessToken(session.accessToken);
    }
    if (session.refreshToken.isNotEmpty) {
      await _store.setRefreshToken(session.refreshToken);
    }
    if (session.userId.isNotEmpty) {
      await _store.setUserId(session.userId);
    }
  }
}
