import '../core/device/device_id.dart';
import '../core/network/api_client.dart';
import '../core/storage/secure_store.dart';

class DeviceSession {
  DeviceSession({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.createdAt,
    required this.lastSeenAt,
    required this.expiresAt,
  });

  final String id;
  final String deviceId;
  final String deviceName;
  final String platform;
  final DateTime? createdAt;
  final DateTime? lastSeenAt;
  final DateTime? expiresAt;

  factory DeviceSession.fromJson(Map<String, dynamic> json) {
    return DeviceSession(
      id: json['id']?.toString() ?? '',
      deviceId: json['deviceId']?.toString() ?? '',
      deviceName: json['deviceName']?.toString() ?? '',
      platform: json['platform']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      lastSeenAt:
          DateTime.tryParse(json['lastSeenAt']?.toString() ?? ''),
      expiresAt:
          DateTime.tryParse(json['expiresAt']?.toString() ?? ''),
    );
  }
}

class SessionService {
  SessionService({SecureStore? store})
      : _store = store ?? SecureStore(),
        _deviceIdStore = DeviceIdStore(store ?? SecureStore()),
        _client = ApiClient(store ?? SecureStore());

  final SecureStore _store;
  final DeviceIdStore _deviceIdStore;
  final ApiClient _client;

  Future<String> currentDeviceId() async {
    return _deviceIdStore.getOrCreate();
  }

  Future<List<DeviceSession>> listSessions() async {
    final data = await _client.post('/auth/sessions', auth: true);
    if (data is! List) return [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(DeviceSession.fromJson)
        .toList();
  }

  Future<void> revokeSession(String deviceId) async {
    await _client.post(
      '/auth/sessions/revoke',
      auth: true,
      body: {'deviceId': deviceId},
    );
  }

  Future<void> revokeOtherSessions(String currentDeviceId) async {
    await _client.post(
      '/auth/sessions/revoke-others',
      auth: true,
      body: {'currentDeviceId': currentDeviceId},
    );
  }

  Future<void> clearLocalSession() async {
    await _store.clearSession();
  }
}
