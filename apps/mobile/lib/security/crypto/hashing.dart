import 'dart:typed_data';

import 'package:sodium_libs/sodium_libs.dart';

import '../bridge/sodium_loader.dart';

/// ============================================================
/// Cryptographic Hashing & Key Derivation
/// ============================================================
/// Implements secure hashing and key derivation functions: 
///
/// • BLAKE2b:  Fast, secure general-purpose hashing
/// • HKDF: Key derivation for Signal Protocol
/// • Argon2id: Password-based key derivation
///
/// Security Level: 256-bit
/// Standards: RFC 7693 (BLAKE2), RFC 5869 (HKDF)
/// ============================================================
final class Hashing {
  Hashing._();

  /// Default hash output length
  static const int defaultHashLength = 32;

  /// Default key derivation length
  static const int defaultKeyLength = 32;

  // ─────────────────────────────────────────────────────────
  // BLAKE2b Hashing
  // ─────────────────────────────────────────────────────────

  /// Compute BLAKE2b hash
  static Future<Uint8List> hash(
    Uint8List data, {
    int outputLength = defaultHashLength,
  }) async {
    _validateOutputLength(outputLength);
    final sodium = await SodiumLoader.sodium;
    return sodium.crypto. genericHash(
      message: data,
      outLen: outputLength,
    );
  }

  /// Compute BLAKE2b hash synchronously
  static Uint8List hashSync(
    Uint8List data, {
    int outputLength = defaultHashLength,
  }) {
    _validateOutputLength(outputLength);
    return SodiumLoader. sodiumSync.crypto.genericHash(
      message:  data,
      outLen: outputLength,
    );
  }

  /// Compute keyed BLAKE2b hash (MAC)
  static Future<Uint8List> keyedHash(
    Uint8List data,
    Uint8List key, {
    int outputLength = defaultHashLength,
  }) async {
    _validateOutputLength(outputLength);
    final sodium = await SodiumLoader.sodium;

    // Convert Uint8List key to SecureKey
    final secureKey = sodium.secureCopy(key);

    try {
      return sodium.crypto.genericHash(
        message:  data,
        key: secureKey,
        outLen:  outputLength,
      );
    } finally {
      secureKey.dispose();
    }
  }

  // ─────────────────────────────────────────────────────────
  // Key Derivation (HKDF-style)
  // ─────────────────────────────────────────────────────────

  /// Derive key using HKDF-style construction
  static Future<Uint8List> deriveKey({
    required Uint8List inputKeyMaterial,
    Uint8List? salt,
    Uint8List? info,
    int outputLength = defaultKeyLength,
  }) async {
    _validateOutputLength(outputLength);
    final sodium = await SodiumLoader.sodium;

    // Extract phase:  PRK = HMAC(salt, IKM)
    Uint8List prk;
    if (salt != null && salt.isNotEmpty) {
      final saltKey = sodium.secureCopy(salt);
      try {
        prk = sodium.crypto. genericHash(
          message:  inputKeyMaterial,
          key: saltKey,
          outLen: 64,
        );
      } finally {
        saltKey.dispose();
      }
    } else {
      prk = sodium.crypto.genericHash(
        message:  inputKeyMaterial,
        outLen: 64,
      );
    }

    // Expand phase with info
    Uint8List okm;
    if (info != null && info.isNotEmpty) {
      okm = sodium.crypto.genericHash(
        message:  Uint8List.fromList([... prk, ...info]),
        outLen:  outputLength,
      );
    } else {
      okm = sodium.crypto. genericHash(
        message: prk,
        outLen: outputLength,
      );
    }

    return okm;
  }

  /// Signal Protocol Root Key KDF
  /// Derives new root key and chain key from DH output
  static Future<RootKeyDerivation> kdfRootKey({
    required Uint8List rootKey,
    required Uint8List dhOutput,
  }) async {
    final sodium = await SodiumLoader.sodium;

    // Combine root key and DH output
    final input = Uint8List.fromList([... rootKey, ...dhOutput]);

    // Derive 64 bytes:  32 for root key, 32 for chain key
    final derived = sodium.crypto. genericHash(
      message: input,
      outLen: 64,
    );

    return RootKeyDerivation(
      rootKey: derived. sublist(0, 32),
      chainKey: derived. sublist(32, 64),
    );
  }

  /// Signal Protocol Chain Key KDF
  /// Advances chain key and derives message key
  static Future<ChainKeyDerivation> kdfChainKey(Uint8List chainKey) async {
    final sodium = await SodiumLoader.sodium;

    // Message key = HMAC(chainKey, 0x01)
    final messageKey = sodium.crypto.genericHash(
      message:  Uint8List.fromList([0x01, ...chainKey]),
      outLen: 32,
    );

    // Next chain key = HMAC(chainKey, 0x02)
    final nextChainKey = sodium.crypto.genericHash(
      message:  Uint8List.fromList([0x02, ...chainKey]),
      outLen:  32,
    );

    return ChainKeyDerivation(
      messageKey: messageKey,
      nextChainKey: nextChainKey,
    );
  }

  // ─────────────────────────────────────────────────────────
  // Password-Based Key Derivation (Argon2id)
  // ─────────────────────────────────────────────────────────

  /// Derive key from password using Argon2id
  static Future<SecureKey> deriveFromPassword({
    required String password,
    required Uint8List salt,
    int outputLength = defaultKeyLength,
    PasswordHashStrength strength = PasswordHashStrength.moderate,
  }) async {
    if (password.isEmpty) {
      throw ArgumentError('Password cannot be empty');
    }
    if (salt.length < 16) {
      throw ArgumentError('Salt must be at least 16 bytes');
    }

    final sodium = await SodiumLoader.sodium;
    final params = _getArgon2Params(strength, sodium);

    // Convert password string to Int8List for pwhash. call
    final passwordBytes = Int8List.fromList(password.codeUnits);

    return sodium.crypto.pwhash. call(
      password: passwordBytes,
      salt: salt,
      outLen: outputLength,
      opsLimit: params.$1,
      memLimit: params.$2,
    );
  }

  /// Generate password hash for storage
  static Future<String> hashPassword(String password) async {
    final sodium = await SodiumLoader.sodium;
    
    // pwhash.str expects String directly
    return sodium.crypto.pwhash.str(
      password: password,
      opsLimit: sodium.crypto.pwhash.opsLimitModerate,
      memLimit: sodium.crypto.pwhash. memLimitModerate,
    );
  }

  /// Verify password against stored hash
  static Future<bool> verifyPassword(String password, String storedHash) async {
    final sodium = await SodiumLoader.sodium;
    
    // pwhash.strVerify expects String for password
    return sodium. crypto.pwhash.strVerify(
      passwordHash: storedHash,
      password: password,
    );
  }

  // ─────────────────────────────────────────────────────────
  // Utility Functions
  // ─────────────────────────────────────────────────────────

  /// Constant-time comparison
  static bool secureEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;

    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }

  /// Compute fingerprint for display (safety number)
  static Future<String> fingerprint(Uint8List publicKey) async {
    final hashResult = await Hashing.hash(publicKey, outputLength: 32);
    return _formatFingerprint(hashResult);
  }

  static String _formatFingerprint(Uint8List hashData) {
    final buffer = StringBuffer();
    for (var i = 0; i < 30; i += 5) {
      if (i > 0) buffer.write(' ');
      final segment = hashData.sublist(i, i + 5);
      final num = segment.fold<int>(0, (acc, b) => (acc << 8) | b);
      buffer.write((num % 100000).toString().padLeft(5, '0'));
    }
    return buffer.toString();
  }

  static void _validateOutputLength(int length) {
    if (length < 16 || length > 64) {
      throw ArgumentError('Output length must be 16-64 bytes:  $length');
    }
  }

  static (int, int) _getArgon2Params(
    PasswordHashStrength strength,
    Sodium sodium,
  ) {
    switch (strength) {
      case PasswordHashStrength.interactive:
        return (
          sodium.crypto. pwhash.opsLimitInteractive,
          sodium.crypto.pwhash. memLimitInteractive,
        );
      case PasswordHashStrength.moderate:
        return (
          sodium.crypto. pwhash. opsLimitModerate,
          sodium. crypto.pwhash.memLimitModerate,
        );
      case PasswordHashStrength.sensitive:
        return (
          sodium.crypto.pwhash. opsLimitSensitive,
          sodium.crypto.pwhash.memLimitSensitive,
        );
    }
  }
}

/// Password hashing strength levels
enum PasswordHashStrength {
  /// Fast, for interactive logins (~100ms)
  interactive,

  /// Balanced, for most use cases (~500ms)
  moderate,

  /// Maximum security, for backups (~3s)
  sensitive,
}

/// Result of root key derivation
class RootKeyDerivation {
  final Uint8List rootKey;
  final Uint8List chainKey;

  const RootKeyDerivation({
    required this.rootKey,
    required this. chainKey,
  });
}

/// Result of chain key derivation
class ChainKeyDerivation {
  final Uint8List messageKey;
  final Uint8List nextChainKey;

  const ChainKeyDerivation({
    required this.messageKey,
    required this. nextChainKey,
  });
}