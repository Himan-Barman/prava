// Multi-device manager
import 'dart:typed_data';

import '../bridge/sodium_loader.dart';
import '../crypto/key_generation.dart';
import '../crypto/random_generator.dart';
import '../crypto/signatures.dart';
import 'device_bundle.dart';
import 'device_identity.dart';
import 'device_registry.dart';

/// ============================================================
/// Multi-Device Manager
/// ============================================================
/// Handles multi-device operations: 
///
/// • Device linking via QR code
/// • Session sync across devices
/// • Device verification
/// • Device revocation
/// ============================================================
final class MultiDeviceManager {
  final DeviceRegistry registry;
  final String _currentDeviceId;

  MultiDeviceManager({
    required this.registry,
    required String currentDeviceId,
  }) : _currentDeviceId = currentDeviceId;

  /// Current device ID
  String get currentDeviceId => _currentDeviceId;

  /// Can device receive messages?
  bool canReceiveMessages(String deviceId) {
    return registry. isTrusted(deviceId);
  }

  /// Get devices to encrypt for (excludes current and revoked)
  List<DeviceIdentity> getEncryptionTargets() {
    return registry.activeDevices
        .where((d) => d.deviceId != _currentDeviceId)
        .toList();
  }

  /// Generate device linking code
  Future<DeviceLinkCode> generateLinkCode() async {
    final sodium = await SodiumLoader.sodium;

    // Generate ephemeral key pair
    final ephemeralKey = sodium.crypto. box. keyPair();

    // Generate challenge
    final challenge = await RandomGenerator.bytes(32);

    return DeviceLinkCode(
      deviceId: _currentDeviceId,
      ephemeralPublicKey: ephemeralKey.publicKey,
      challenge: challenge,
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
    );
  }

  /// Process device link request
  Future<DeviceLinkResult> linkDevice({
    required DeviceLinkRequest request,
    required Uint8List identityPrivateKey,
  }) async {
    // Verify signature
    final sodium = await SodiumLoader.sodium;
    final secretKey = sodium.secureCopy(identityPrivateKey);

    final signatureValid = await Signatures. verify(
      request.challenge,
      request.signature,
      request.devicePublicKey,
    );

    secretKey.dispose();

    if (!signatureValid) {
      return DeviceLinkResult. failure('Invalid device signature');
    }

    // Create device identity
    final device = DeviceIdentity(
      deviceId: request.deviceId,
      trust: DeviceTrust.secondary,
      publicKey: request.devicePublicKey. toList(),
      registrationId: request. registrationId,
      name: request. deviceName,
      platform: request.platform,
      createdAt: DateTime. now().millisecondsSinceEpoch,
    );

    // Register device
    registry.register(device);

    return DeviceLinkResult. success(device);
  }

  /// Revoke a device
  Future<void> revokeDevice(String deviceId) async {
    if (deviceId == _currentDeviceId) {
      throw ArgumentError('Cannot revoke current device');
    }

    registry.revoke(deviceId);

    // Note: Caller should also: 
    // 1. Notify server
    // 2. Rotate sender keys in all groups
    // 3. Reset sessions with this device
  }

  /// Verify device fingerprint
  Future<bool> verifyFingerprint({
    required String deviceId,
    required Uint8List expectedFingerprint,
  }) async {
    final device = registry.get(deviceId);
    if (device == null) return false;

    final sodium = await SodiumLoader.sodium;
    final actualFingerprint = sodium.crypto.genericHash(
      message:  Uint8List.fromList(device.publicKey),
      outLen: 32,
    );

    // Constant-time comparison
    if (actualFingerprint.length != expectedFingerprint.length) {
      return false;
    }

    var result = 0;
    for (var i = 0; i < actualFingerprint.length; i++) {
      result |= actualFingerprint[i] ^ expectedFingerprint[i];
    }

    return result == 0;
  }

  /// Get device fingerprint for display
  Future<String> getDeviceFingerprint(String deviceId) async {
    final device = registry.get(deviceId);
    if (device == null) {
      throw ArgumentError('Device not found:  $deviceId');
    }

    final sodium = await SodiumLoader.sodium;
    final hash = sodium.crypto. genericHash(
      message: Uint8List.fromList(device.publicKey),
      outLen:  32,
    );

    // Format as safety number (groups of 5 digits)
    final buffer = StringBuffer();
    for (var i = 0; i < 30; i += 5) {
      if (i > 0) buffer.write(' ');
      final segment = hash.sublist(i, i + 5);
      final num = segment.fold<int>(0, (acc, b) => (acc << 8) | b);
      buffer.write((num % 100000).toString().padLeft(5, '0'));
    }
    return buffer.toString();
  }
}

/// Device linking code (for QR)
class DeviceLinkCode {
  final String deviceId;
  final Uint8List ephemeralPublicKey;
  final Uint8List challenge;
  final DateTime expiresAt;

  const DeviceLinkCode({
    required this.deviceId,
    required this.ephemeralPublicKey,
    required this.challenge,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'ephemeralPublicKey': ephemeralPublicKey.toList(),
        'challenge': challenge.toList(),
        'expiresAt': expiresAt. millisecondsSinceEpoch,
      };
}

/// Device link request
class DeviceLinkRequest {
  final String deviceId;
  final Uint8List devicePublicKey;
  final int registrationId;
  final Uint8List challenge;
  final Uint8List signature;
  final String?  deviceName;
  final String? platform;

  const DeviceLinkRequest({
    required this.deviceId,
    required this.devicePublicKey,
    required this.registrationId,
    required this.challenge,
    required this.signature,
    this.deviceName,
    this.platform,
  });

  factory DeviceLinkRequest. fromJson(Map<String, dynamic> json) {
    return DeviceLinkRequest(
      deviceId: json['deviceId'] as String,
      devicePublicKey:  Uint8List.fromList(
        (json['devicePublicKey'] as List).cast<int>(),
      ),
      registrationId: json['registrationId'] as int,
      challenge: Uint8List.fromList((json['challenge'] as List).cast<int>()),
      signature: Uint8List.fromList((json['signature'] as List).cast<int>()),
      deviceName: json['deviceName'] as String?,
      platform: json['platform'] as String?,
    );
  }
}

/// Device link result
class DeviceLinkResult {
  final bool success;
  final DeviceIdentity?  device;
  final String? error;

  const DeviceLinkResult._({
    required this. success,
    this.device,
    this.error,
  });

  factory DeviceLinkResult.success(DeviceIdentity device) =>
      DeviceLinkResult. _(success: true, device: device);

  factory DeviceLinkResult.failure(String error) =>
      DeviceLinkResult._(success: false, error: error);
}