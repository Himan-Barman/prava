// Device registry
import 'dart:collection';

import 'device_identity.dart';

/// ============================================================
/// Device Registry
/// ============================================================
/// Manages all devices for a user account.
/// ============================================================
final class DeviceRegistry {
  final Map<String, DeviceIdentity> _devices = {};
  final String _userId;

  DeviceRegistry(this._userId);

  /// User ID for this registry
  String get userId => _userId;

  /// Number of devices
  int get deviceCount => _devices.length;

  /// Number of active devices
  int get activeDeviceCount => activeDevices.length;

  /// Register a new device
  void register(DeviceIdentity device) {
    if (device.trust == DeviceTrust.revoked) {
      throw ArgumentError('Cannot register a revoked device');
    }
    _devices[device.deviceId] = device;
  }

  /// Get device by ID
  DeviceIdentity?  get(String deviceId) => _devices[deviceId];

  /// Check if device exists
  bool hasDevice(String deviceId) => _devices.containsKey(deviceId);

  /// Check if device is trusted
  bool isTrusted(String deviceId) {
    final device = _devices[deviceId];
    return device != null && device.canReceive;
  }

  /// Revoke a device
  void revoke(String deviceId) {
    final device = _devices[deviceId];
    if (device != null) {
      _devices[deviceId] = device.revoke();
    }
  }

  /// Remove a device completely
  DeviceIdentity?  remove(String deviceId) {
    return _devices.remove(deviceId);
  }

  /// Update device last seen
  void updateLastSeen(String deviceId) {
    final device = _devices[deviceId];
    if (device != null) {
      _devices[deviceId] = device.updateLastSeen();
    }
  }

  /// Get all devices
  List<DeviceIdentity> get allDevices =>
      UnmodifiableListView(_devices.values. toList());

  /// Get trusted devices (can receive)
  List<DeviceIdentity> get trustedDevices =>
      UnmodifiableListView(_devices. values.where((d) => d.canReceive).toList());

  /// Get active devices (can send)
  List<DeviceIdentity> get activeDevices =>
      UnmodifiableListView(_devices.values.where((d) => d.isActive).toList());

  /// Get primary device
  DeviceIdentity? get primaryDevice =>
      _devices. values.where((d) => d.trust == DeviceTrust.primary).firstOrNull;

  /// Get revoked devices
  List<DeviceIdentity> get revokedDevices =>
      UnmodifiableListView(
        _devices. values.where((d) => d.trust == DeviceTrust.revoked).toList(),
      );

  /// Clear all devices
  void clear() {
    _devices.clear();
  }

  /// Serialize to JSON
  Map<String, dynamic> toJson() => {
        'userId': _userId,
        'devices': _devices. map((k, v) => MapEntry(k, v.toJson())),
      };

  /// Deserialize from JSON
  factory DeviceRegistry.fromJson(Map<String, dynamic> json) {
    final registry = DeviceRegistry(json['userId'] as String);
    final devices = json['devices'] as Map<String, dynamic>;
    
    for (final entry in devices.entries) {
      registry._devices[entry.key] = DeviceIdentity.fromJson(
        entry.value as Map<String, dynamic>,
      );
    }
    
    return registry;
  }

  @override
  String toString() => 'DeviceRegistry(userId: $_userId, devices: $deviceCount)';
}