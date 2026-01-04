// Key distribution protocol
import 'dart:typed_data';

import '../crypto/key_generation.dart';
import '../crypto/random_generator.dart';
import '../device/device_bundle.dart';
import '../storage/prekey_store.dart';
import '../storage/signed_prekey_store.dart';

/// ============================================================
/// Key Distribution
/// ============================================================
/// Manages key distribution for X3DH: 
///
/// • Generate and upload key bundles
/// • Replenish pre-keys
/// • Rotate signed pre-keys
/// ============================================================
final class KeyDistribution {
  KeyDistribution._();

  /// Default pre-key batch size
  static const int preKeyBatchSize = 100;

  /// Pre-key replenishment threshold
  static const int preKeyThreshold = 20;

  /// Generate initial key bundle for registration
  static Future<InitialKeyBundle> generateInitialBundle({
    required String deviceId,
    required int registrationId,
    required Uint8List identityPublicKey,
    required dynamic identityPrivateKey, // SecureKey
  }) async {
    // Generate signed pre-key
    final signedPreKeyId = await KeyGeneration.generateKeyId();
    final signedPreKey = await KeyGeneration.generateSignedPreKey(
      keyId: signedPreKeyId,
      identityPrivateKey: identityPrivateKey,
    );

    // Generate one-time pre-keys
    final preKeyStartId = await PreKeyStore.getNextKeyId();
    final preKeys = await KeyGeneration.generateOneTimePreKeyBatch(
      startId: preKeyStartId,
      count: preKeyBatchSize,
    );

    // Save signed pre-key
    await SignedPreKeyStore.saveSignedPreKey(
      keyId: signedPreKey.keyId,
      publicKey: signedPreKey.publicKey,
      privateKey:  signedPreKey. secretKey. extractBytes(),
      signature: signedPreKey.signature,
    );

    // Save pre-keys
    await PreKeyStore.savePreKeyBatch(
      preKeys. map((pk) => PreKeyData(
        keyId: pk.keyId,
        publicKey: pk.publicKey,
        privateKey: pk.secretKey.extractBytes(),
      )).toList(),
    );

    return InitialKeyBundle(
      deviceId:  deviceId,
      registrationId: registrationId,
      identityKey: identityPublicKey,
      signedPreKey: signedPreKey. publicKey,
      signedPreKeyId:  signedPreKey.keyId,
      signedPreKeySignature: signedPreKey.signature,
      oneTimePreKeys: preKeys.map((pk) => PreKeyInfo(
        keyId: pk.keyId,
        publicKey: pk.publicKey,
      )).toList(),
    );
  }

  /// Check if pre-keys need replenishment
  static Future<bool> needsPreKeyReplenishment() async {
    return PreKeyStore.needsReplenishment();
  }

  /// Generate additional pre-keys
  static Future<List<PreKeyInfo>> replenishPreKeys({
    int count = preKeyBatchSize,
  }) async {
    final startId = await PreKeyStore.getNextKeyId();
    final preKeys = await KeyGeneration.generateOneTimePreKeyBatch(
      startId: startId,
      count: count,
    );

    // Save to store
    await PreKeyStore.savePreKeyBatch(
      preKeys.map((pk) => PreKeyData(
        keyId: pk.keyId,
        publicKey: pk.publicKey,
        privateKey: pk.secretKey.extractBytes(),
      )).toList(),
    );

    return preKeys.map((pk) => PreKeyInfo(
      keyId:  pk.keyId,
      publicKey:  pk.publicKey,
    )).toList();
  }

  /// Check if signed pre-key needs rotation
  static Future<bool> needsSignedPreKeyRotation() async {
    return SignedPreKeyStore.needsRotation();
  }

  /// Rotate signed pre-key
  static Future<SignedPreKeyInfo> rotateSignedPreKey({
    required dynamic identityPrivateKey, // SecureKey
  }) async {
    final keyId = await SignedPreKeyStore.getNextKeyId();
    final signedPreKey = await KeyGeneration.generateSignedPreKey(
      keyId: keyId,
      identityPrivateKey: identityPrivateKey,
    );

    // Save new key (automatically deactivates old)
    await SignedPreKeyStore.saveSignedPreKey(
      keyId:  signedPreKey.keyId,
      publicKey: signedPreKey.publicKey,
      privateKey:  signedPreKey. secretKey.extractBytes(),
      signature: signedPreKey. signature,
    );

    // Delete old keys
    await SignedPreKeyStore.deleteOld();

    return SignedPreKeyInfo(
      keyId:  signedPreKey.keyId,
      publicKey: signedPreKey.publicKey,
      signature: signedPreKey.signature,
    );
  }

  /// Get current device bundle for upload
  static Future<DeviceBundle? > getCurrentBundle({
    required String deviceId,
    required int registrationId,
    required Uint8List identityKey,
  }) async {
    final signedPreKey = await SignedPreKeyStore.getCurrentSignedPreKey();
    if (signedPreKey == null) return null;

    final preKeys = await PreKeyStore.getPendingUpload();

    return DeviceBundle(
      deviceId: deviceId,
      registrationId:  registrationId,
      identityKey:  identityKey,
      signedPreKey:  Uint8List.fromList(signedPreKey.publicKey),
      signedPreKeyId:  signedPreKey. keyId,
      signedPreKeySignature:  Uint8List.fromList(signedPreKey.signature),
      oneTimePreKeys: preKeys.map((pk) => PreKeyInfo(
        keyId: pk. keyId,
        publicKey:  Uint8List.fromList(pk.publicKey),
      )).toList(),
    );
  }

  /// Mark pre-keys as uploaded
  static Future<void> markPreKeysUploaded(List<int> keyIds) async {
    await PreKeyStore.markUploaded(keyIds);
  }
}

/// Initial key bundle for registration
class InitialKeyBundle {
  final String deviceId;
  final int registrationId;
  final Uint8List identityKey;
  final Uint8List signedPreKey;
  final int signedPreKeyId;
  final Uint8List signedPreKeySignature;
  final List<PreKeyInfo> oneTimePreKeys;

  const InitialKeyBundle({
    required this. deviceId,
    required this.registrationId,
    required this.identityKey,
    required this.signedPreKey,
    required this.signedPreKeyId,
    required this.signedPreKeySignature,
    required this.oneTimePreKeys,
  });

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'registrationId': registrationId,
        'identityKey': identityKey. toList(),
        'signedPreKey': signedPreKey.toList(),
        'signedPreKeyId': signedPreKeyId,
        'signedPreKeySignature': signedPreKeySignature.toList(),
        'oneTimePreKeys': oneTimePreKeys.map((pk) => pk.toJson()).toList(),
      };
}

/// Signed pre-key info for upload
class SignedPreKeyInfo {
  final int keyId;
  final Uint8List publicKey;
  final Uint8List signature;

  const SignedPreKeyInfo({
    required this.keyId,
    required this.publicKey,
    required this.signature,
  });

  Map<String, dynamic> toJson() => {
        'keyId': keyId,
        'publicKey': publicKey.toList(),
        'signature': signature.toList(),
      };
}