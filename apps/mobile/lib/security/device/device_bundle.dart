// Device bundle
import 'dart:typed_data';

/// ============================================================
/// Device Bundle
/// ============================================================
/// Public prekey bundle for X3DH key agreement.
/// Retrieved from server when initiating a session.
/// ============================================================
final class DeviceBundle {
  /// Device identifier
  final String deviceId;

  /// Registration ID
  final int registrationId;

  /// Ed25519 identity public key
  final Uint8List identityKey;

  /// X25519 signed pre-key public
  final Uint8List signedPreKey;

  /// Signed pre-key ID
  final int signedPreKeyId;

  /// Signature over signed pre-key
  final Uint8List signedPreKeySignature;

  /// Available one-time pre-keys
  final List<PreKeyInfo> oneTimePreKeys;

  const DeviceBundle({
    required this.deviceId,
    required this.registrationId,
    required this.identityKey,
    required this. signedPreKey,
    required this. signedPreKeyId,
    required this.signedPreKeySignature,
    required this.oneTimePreKeys,
  });

  /// Get first available one-time pre-key
  PreKeyInfo? get firstOneTimePreKey =>
      oneTimePreKeys.isNotEmpty ? oneTimePreKeys.first :  null;

  /// Has one-time pre-keys available
  bool get hasOneTimePreKeys => oneTimePreKeys. isNotEmpty;

  /// Serialize to JSON
  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'registrationId': registrationId,
        'identityKey': identityKey. toList(),
        'signedPreKey':  signedPreKey. toList(),
        'signedPreKeyId': signedPreKeyId,
        'signedPreKeySignature': signedPreKeySignature. toList(),
        'oneTimePreKeys': oneTimePreKeys.map((pk) => pk.toJson()).toList(),
      };

  /// Deserialize from JSON
  factory DeviceBundle. fromJson(Map<String, dynamic> json) {
    return DeviceBundle(
      deviceId: json['deviceId'] as String,
      registrationId: json['registrationId'] as int,
      identityKey:  Uint8List.fromList(
        (json['identityKey'] as List).cast<int>(),
      ),
      signedPreKey: Uint8List.fromList(
        (json['signedPreKey'] as List).cast<int>(),
      ),
      signedPreKeyId: json['signedPreKeyId'] as int,
      signedPreKeySignature: Uint8List.fromList(
        (json['signedPreKeySignature'] as List).cast<int>(),
      ),
      oneTimePreKeys: (json['oneTimePreKeys'] as List?)
              ?.map((e) => PreKeyInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// One-time pre-key info
class PreKeyInfo {
  final int keyId;
  final Uint8List publicKey;

  const PreKeyInfo({
    required this.keyId,
    required this.publicKey,
  });

  Map<String, dynamic> toJson() => {
        'keyId': keyId,
        'publicKey': publicKey.toList(),
      };

  factory PreKeyInfo.fromJson(Map<String, dynamic> json) {
    return PreKeyInfo(
      keyId: json['keyId'] as int,
      publicKey: Uint8List.fromList((json['publicKey'] as List).cast<int>()),
    );
  }
}