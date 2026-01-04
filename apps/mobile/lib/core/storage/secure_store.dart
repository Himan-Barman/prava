import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStore {
  static const _accessTokenKey = 'accessToken';
  static const _refreshTokenKey = 'refreshToken';
  static const _deviceIdKey = 'deviceId';
  static const _userIdKey = 'userId';
  static const _settingsKey = 'userSettings';
  static const _chatSyncStateKey = 'chatSyncState';
  static const _e2eeIdentityXPublicKey = 'e2eeIdentityXPublicKey';
  static const _e2eeIdentityXPrivateKey = 'e2eeIdentityXPrivateKey';

  final FlutterSecureStorage _storage =
      const FlutterSecureStorage();

  Future<void> setAccessToken(String token) {
    return _storage.write(key: _accessTokenKey, value: token);
  }

  Future<String?> getAccessToken() {
    return _storage.read(key: _accessTokenKey);
  }

  Future<void> setRefreshToken(String token) {
    return _storage.write(key: _refreshTokenKey, value: token);
  }

  Future<String?> getRefreshToken() {
    return _storage.read(key: _refreshTokenKey);
  }

  Future<void> setDeviceId(String deviceId) {
    return _storage.write(key: _deviceIdKey, value: deviceId);
  }

  Future<String?> getDeviceId() {
    return _storage.read(key: _deviceIdKey);
  }

  Future<void> setUserId(String userId) {
    return _storage.write(key: _userIdKey, value: userId);
  }

  Future<String?> getUserId() {
    return _storage.read(key: _userIdKey);
  }

  Future<void> setSettingsJson(String settings) {
    return _storage.write(key: _settingsKey, value: settings);
  }

  Future<String?> getSettingsJson() {
    return _storage.read(key: _settingsKey);
  }

  Future<void> setChatSyncStateJson(String state) {
    return _storage.write(key: _chatSyncStateKey, value: state);
  }

  Future<String?> getChatSyncStateJson() {
    return _storage.read(key: _chatSyncStateKey);
  }

  Future<void> clearChatSyncState() {
    return _storage.delete(key: _chatSyncStateKey);
  }

  Future<void> clearSettings() {
    return _storage.delete(key: _settingsKey);
  }

  Future<void> setE2eeIdentityXPublicKey(String value) {
    return _storage.write(key: _e2eeIdentityXPublicKey, value: value);
  }

  Future<String?> getE2eeIdentityXPublicKey() {
    return _storage.read(key: _e2eeIdentityXPublicKey);
  }

  Future<void> setE2eeIdentityXPrivateKey(String value) {
    return _storage.write(key: _e2eeIdentityXPrivateKey, value: value);
  }

  Future<String?> getE2eeIdentityXPrivateKey() {
    return _storage.read(key: _e2eeIdentityXPrivateKey);
  }

  Future<void> clearE2eeIdentityXKeys() async {
    await _storage.delete(key: _e2eeIdentityXPublicKey);
    await _storage.delete(key: _e2eeIdentityXPrivateKey);
  }

  Future<void> clearSession() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _settingsKey);
    await _storage.delete(key: _chatSyncStateKey);
    await _storage.delete(key: _e2eeIdentityXPublicKey);
    await _storage.delete(key: _e2eeIdentityXPrivateKey);
  }
}
