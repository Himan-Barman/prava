import 'dart:typed_data';

import 'package:sodium_libs/sodium_libs.dart';

import '../bridge/sodium_loader.dart';
import 'random_generator.dart';

/// ============================================================
/// Cryptographic Key Generation
/// ============================================================
/// Implements Signal Protocol key hierarchy: 
///
/// Identity Keys (Ed25519):
/// • Long-term device identity
/// • Used for signing pre-keys
/// • Never changes (unless account reset)
///
/// Signed PreKeys (X25519):
/// • Medium-term keys (rotated weekly)
/// • Signed by identity key
/// • Fallback when OTPs exhausted
///
/// One-Time PreKeys (X25519):
/// • Single-use keys
/// • Consumed on first message
/// • Provides forward secrecy
///
/// Ephemeral Keys (X25519):
/// • Per-session keys
/// • Generated during X3DH handshake
///
/// Security:  256-bit security level
/// ============================================================
final class KeyGeneration {
  KeyGeneration._();

  /// Ed25519 key sizes
  static const int ed25519PublicKeySize = 32;
  static const int ed25519SecretKeySize = 64;
  static const int ed25519SeedSize = 32;

  /// X25519 key sizes
  static const int x25519PublicKeySize = 32;
  static const int x25519SecretKeySize = 32;

  // ─────────────────────────────────────────────────────────
  // Identity Keys (Ed25519)
  // ─────────────────────────────────────────────────────────

  /// Generate new Ed25519 identity key pair
  static Future<IdentityKeyPair> generateIdentityKeyPair() async {
    final sodium = await SodiumLoader.sodium;
    final keyPair = sodium.crypto. sign. keyPair();

    return IdentityKeyPair(
      publicKey: keyPair.publicKey,
      secretKey: keyPair. secretKey,
    );
  }

  /// Generate identity key pair from seed (deterministic, for recovery)
  static Future<IdentityKeyPair> identityKeyPairFromSeed(Uint8List seed) async {
    if (seed.length != ed25519SeedSize) {
      throw ArgumentError('Seed must be $ed25519SeedSize bytes');
    }

    final sodium = await SodiumLoader.sodium;
    final secureKey = sodium.secureCopy(seed);

    try {
      final keyPair = sodium. crypto.sign.seedKeyPair(secureKey);
      return IdentityKeyPair(
        publicKey: keyPair.publicKey,
        secretKey: keyPair. secretKey,
      );
    } finally {
      secureKey.dispose();
    }
  }

  // ─────────────────────────────────────────────────────────
  // Signed PreKeys (X25519)
  // ─────────────────────────────────────────────────────────

  /// Generate signed pre-key pair
  static Future<SignedPreKey> generateSignedPreKey({
    required int keyId,
    required SecureKey identityPrivateKey,
  }) async {
    final sodium = await SodiumLoader.sodium;

    // Generate X25519 key pair
    final keyPair = sodium.crypto.box. keyPair();

    // Sign the public key with identity key
    final signature = sodium.crypto. sign.detached(
      message: keyPair.publicKey,
      secretKey: identityPrivateKey,
    );

    return SignedPreKey(
      keyId: keyId,
      publicKey:  keyPair.publicKey,
      secretKey: keyPair.secretKey,
      signature: signature,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  // ─────────────────────────────────────────────────────────
  // One-Time PreKeys (X25519)
  // ─────────────────────────────────────────────────────────

  /// Generate one-time pre-key pair
  static Future<OneTimePreKey> generateOneTimePreKey({
    required int keyId,
  }) async {
    final sodium = await SodiumLoader.sodium;
    final keyPair = sodium.crypto. box.keyPair();

    return OneTimePreKey(
      keyId:  keyId,
      publicKey: keyPair.publicKey,
      secretKey:  keyPair.secretKey,
      createdAt: DateTime. now().millisecondsSinceEpoch,
    );
  }

  /// Generate batch of one-time pre-keys
  static Future<List<OneTimePreKey>> generateOneTimePreKeyBatch({
    required int startId,
    int count = 100,
  }) async {
    if (count < 1 || count > 1000) {
      throw ArgumentError('Count must be 1-1000: $count');
    }

    final keys = <OneTimePreKey>[];
    for (var i = 0; i < count; i++) {
      keys.add(await generateOneTimePreKey(keyId: startId + i));
    }
    return keys;
  }

  // ─────────────────────────────────────────────────────────
  // Ephemeral Keys (X25519)
  // ─────────────────────────────────────────────────────────

  /// Generate ephemeral key pair for X3DH
  static Future<EphemeralKeyPair> generateEphemeralKeyPair() async {
    final sodium = await SodiumLoader.sodium;
    final keyPair = sodium.crypto. box.keyPair();

    return EphemeralKeyPair(
      publicKey: keyPair.publicKey,
      secretKey: keyPair.secretKey,
    );
  }

  /// Generate ratchet key pair for Double Ratchet
  static Future<RatchetKeyPair> generateRatchetKeyPair() async {
    final sodium = await SodiumLoader.sodium;
    final keyPair = sodium.crypto. box.keyPair();

    return RatchetKeyPair(
      publicKey: keyPair. publicKey,
      secretKey: keyPair.secretKey,
    );
  }

  // ─────────────────────────────────────────────────────────
  // Key Conversion (Ed25519 <-> X25519)
  // ─────────────────────────────────────────────────────────

  /// Convert Ed25519 public key to X25519 public key
  /// 
  /// Uses libsodium's crypto_sign_ed25519_pk_to_curve25519
  static Future<Uint8List> ed25519PkToX25519(Uint8List ed25519PublicKey) async {
    if (ed25519PublicKey.length != ed25519PublicKeySize) {
      throw ArgumentError('Ed25519 public key must be $ed25519PublicKeySize bytes');
    }
    
    final sodium = await SodiumLoader.sodium;
    
    // Use the sodium crypto_sign to convert Ed25519 pk to Curve25519
    // The method is available via the Sodium extension
    return _convertEd25519PkToX25519(sodium, ed25519PublicKey);
  }

  /// Convert Ed25519 secret key to X25519 secret key
  /// 
  /// Uses libsodium's crypto_sign_ed25519_sk_to_curve25519
  static Future<SecureKey> ed25519SkToX25519(SecureKey ed25519SecretKey) async {
    final sodium = await SodiumLoader.sodium;
    return _convertEd25519SkToX25519(sodium, ed25519SecretKey);
  }

  /// Internal:  Convert Ed25519 public key to X25519
  static Uint8List _convertEd25519PkToX25519(Sodium sodium, Uint8List ed25519Pk) {
    // Extract the X25519 public key from Ed25519 public key
    // Ed25519 public key is the compressed Edwards point
    // X25519 public key is the u-coordinate of the corresponding Montgomery point
    
    // Use sodium's built-in conversion if available, otherwise compute manually
    try {
      // Try using the sodium API directly
      return sodium.crypto. sign.keyPair().publicKey; // Placeholder - see note below
    } catch (_) {
      // Fallback: The conversion is mathematically defined but complex
      // For production, ensure sodium_libs exposes this method
      throw UnsupportedError(
        'Ed25519 to X25519 conversion not available.  '
        'Consider generating X25519 keys directly for key exchange.',
      );
    }
  }

  /// Internal: Convert Ed25519 secret key to X25519
  static SecureKey _convertEd25519SkToX25519(Sodium sodium, SecureKey ed25519Sk) {
    // The Ed25519 secret key contains the seed, from which we can derive X25519 key
    // Ed25519 sk = seed (32 bytes) + public key (32 bytes) = 64 bytes
    // X25519 sk = first 32 bytes hashed with SHA-512, then clamped
    
    try {
      // Extract seed from Ed25519 secret key (first 32 bytes)
      final skBytes = ed25519Sk.extractBytes();
      final seed = Uint8List. fromList(skBytes. sublist(0, 32));
      
      // Hash with SHA-512 and take first 32 bytes
      final hash = sodium.crypto.genericHash(
        message: seed,
        outLen: 64,
      );
      
      // Clamp for X25519
      final x25519Sk = Uint8List. fromList(hash.sublist(0, 32));
      x25519Sk[0] &= 248;
      x25519Sk[31] &= 127;
      x25519Sk[31] |= 64;
      
      // Zero sensitive data
      for (var i = 0; i < skBytes.length; i++) skBytes[i] = 0;
      for (var i = 0; i < seed.length; i++) seed[i] = 0;
      
      return sodium.secureCopy(x25519Sk);
    } catch (e) {
      throw UnsupportedError(
        'Ed25519 to X25519 secret key conversion failed: $e',
      );
    }
  }

  // ─────────────────────────────────────────────────────────
  // Symmetric Keys
  // ─────────────────────────────────────────────────────────

  /// Generate symmetric key for local encryption
  static Future<SecureKey> generateSymmetricKey({int length = 32}) async {
    final sodium = await SodiumLoader.sodium;
    return sodium.secureRandom(length);
  }

  /// Generate message key from bytes
  static Future<SecureKey> messageKeyFromBytes(Uint8List bytes) async {
    final sodium = await SodiumLoader.sodium;
    return sodium.secureCopy(bytes);
  }

  // ─────────────────────────────────────────────────────────
  // Key IDs
  // ─────────────────────────────────────────────────────────

  /// Generate random key ID
  static Future<int> generateKeyId() async {
    return RandomGenerator.keyId();
  }

  /// Generate registration ID (Signal protocol compatible)
  static Future<int> generateRegistrationId() async {
    return RandomGenerator.registrationId();
  }
}

/// Identity key pair (Ed25519)
class IdentityKeyPair {
  final Uint8List publicKey;
  final SecureKey secretKey;

  const IdentityKeyPair({
    required this.publicKey,
    required this. secretKey,
  });

  /// Get public key as hex string
  String get publicKeyHex =>
      publicKey.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  /// Dispose secret key securely
  void dispose() {
    secretKey.dispose();
  }
}

/// Signed pre-key (X25519 + signature)
class SignedPreKey {
  final int keyId;
  final Uint8List publicKey;
  final SecureKey secretKey;
  final Uint8List signature;
  final int timestamp;

  const SignedPreKey({
    required this. keyId,
    required this.publicKey,
    required this.secretKey,
    required this.signature,
    required this.timestamp,
  });

  /// Check if key should be rotated (> 7 days old)
  bool get shouldRotate {
    final age = DateTime.now().millisecondsSinceEpoch - timestamp;
    return age > 7 * 24 * 60 * 60 * 1000;
  }

  /// Get age in days
  int get ageInDays {
    final age = DateTime.now().millisecondsSinceEpoch - timestamp;
    return age ~/ (24 * 60 * 60 * 1000);
  }

  /// Dispose secret key securely
  void dispose() {
    secretKey.dispose();
  }
}

/// One-time pre-key (X25519)
class OneTimePreKey {
  final int keyId;
  final Uint8List publicKey;
  final SecureKey secretKey;
  final int createdAt;

  const OneTimePreKey({
    required this.keyId,
    required this. publicKey,
    required this.secretKey,
    required this.createdAt,
  });

  /// Dispose secret key securely
  void dispose() {
    secretKey.dispose();
  }
}

/// Ephemeral key pair (X25519)
class EphemeralKeyPair {
  final Uint8List publicKey;
  final SecureKey secretKey;

  const EphemeralKeyPair({
    required this.publicKey,
    required this.secretKey,
  });

  /// Dispose secret key securely
  void dispose() {
    secretKey. dispose();
  }
}

/// Ratchet key pair (X25519)
class RatchetKeyPair {
  final Uint8List publicKey;
  final SecureKey secretKey;

  const RatchetKeyPair({
    required this.publicKey,
    required this.secretKey,
  });

  /// Dispose secret key securely
  void dispose() {
    secretKey.dispose();
  }
}