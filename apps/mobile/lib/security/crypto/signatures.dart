// Ed25519 signatures
import 'dart:typed_data';

import 'package:sodium_libs/sodium_libs.dart';

import '../bridge/sodium_loader.dart';

/// ============================================================
/// Digital Signatures (Ed25519)
/// ============================================================
/// Implements Ed25519 digital signatures: 
///
/// • Detached signatures (signature separate from message)
/// • Combined signatures (signature prepended to message)
/// • Pre-key signing for X3DH
/// • Batch verification support
///
/// Security: 
/// • 128-bit security level (256-bit curve)
/// • Deterministic (no random needed for signing)
/// • SUF-CMA secure (strong unforgeability)
///
/// Standards:  RFC 8032 (Ed25519)
/// ============================================================
final class Signatures {
  Signatures._();

  /// Ed25519 signature size in bytes
  static const int signatureBytes = 64;

  /// Ed25519 public key size in bytes
  static const int publicKeyBytes = 32;

  /// Ed25519 secret key size in bytes
  static const int secretKeyBytes = 64;

  // ─────────────────────────────────────────────────────────
  // Detached Signatures
  // ─────────────────────────────────────────────────────────

  /// Create detached signature
  static Future<Uint8List> sign(
    Uint8List message,
    SecureKey secretKey,
  ) async {
    final sodium = await SodiumLoader.sodium;
    return sodium.crypto.sign.detached(
      message: message,
      secretKey:  secretKey,
    );
  }

  /// Create detached signature synchronously
  static Uint8List signSync(
    Uint8List message,
    SecureKey secretKey,
  ) {
    return SodiumLoader.sodiumSync.crypto.sign. detached(
      message: message,
      secretKey: secretKey,
    );
  }

  /// Verify detached signature
  static Future<bool> verify(
    Uint8List message,
    Uint8List signature,
    Uint8List publicKey,
  ) async {
    if (! _validateInputs(signature, publicKey)) {
      return false;
    }

    try {
      final sodium = await SodiumLoader.sodium;
      return sodium.crypto.sign.verifyDetached(
        message: message,
        signature: signature,
        publicKey: publicKey,
      );
    } catch (_) {
      return false;
    }
  }

  /// Verify detached signature synchronously
  static bool verifySync(
    Uint8List message,
    Uint8List signature,
    Uint8List publicKey,
  ) {
    if (!_validateInputs(signature, publicKey)) {
      return false;
    }

    try {
      return SodiumLoader.sodiumSync.crypto. sign.verifyDetached(
        message: message,
        signature: signature,
        publicKey: publicKey,
      );
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────
  // Combined Signatures
  // ─────────────────────────────────────────────────────────

  /// Create combined signature (signature prepended to message)
  static Future<Uint8List> signCombined(
    Uint8List message,
    SecureKey secretKey,
  ) async {
    final sodium = await SodiumLoader.sodium;
    return sodium.crypto. sign.call(
      message: message,
      secretKey: secretKey,
    );
  }

  /// Open and verify combined signature
  static Future<Uint8List? > openCombined(
    Uint8List signedMessage,
    Uint8List publicKey,
  ) async {
    if (publicKey.length != publicKeyBytes) {
      return null;
    }
    if (signedMessage. length < signatureBytes) {
      return null;
    }

    try {
      final sodium = await SodiumLoader.sodium;
      return sodium.crypto.sign.open(
        signedMessage: signedMessage,
        publicKey:  publicKey,
      );
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────
  // Pre-Key Signatures (for X3DH)
  // ─────────────────────────────────────────────────────────

  /// Sign pre-key public key with identity key
  static Future<Uint8List> signPreKey(
    Uint8List preKeyPublic,
    SecureKey identitySecretKey,
  ) async {
    return sign(preKeyPublic, identitySecretKey);
  }

  /// Verify pre-key signature
  static Future<bool> verifyPreKey(
    Uint8List preKeyPublic,
    Uint8List signature,
    Uint8List identityPublicKey,
  ) async {
    return verify(preKeyPublic, signature, identityPublicKey);
  }

  // ─────────────────────────────────────────────────────────
  // Batch Operations
  // ─────────────────────────────────────────────────────────

  /// Sign multiple messages
  static Future<List<Uint8List>> signBatch(
    List<Uint8List> messages,
    SecureKey secretKey,
  ) async {
    final signatures = <Uint8List>[];
    for (final message in messages) {
      signatures.add(await sign(message, secretKey));
    }
    return signatures;
  }

  /// Verify multiple signatures (all must be valid)
  static Future<bool> verifyBatch(
    List<Uint8List> messages,
    List<Uint8List> signatures,
    Uint8List publicKey,
  ) async {
    if (messages.length != signatures. length) {
      return false;
    }

    for (var i = 0; i < messages.length; i++) {
      if (!await verify(messages[i], signatures[i], publicKey)) {
        return false;
      }
    }
    return true;
  }

  /// Verify multiple signatures (returns list of results)
  static Future<List<bool>> verifyBatchIndividual(
    List<Uint8List> messages,
    List<Uint8List> signatures,
    Uint8List publicKey,
  ) async {
    if (messages.length != signatures.length) {
      return List.filled(messages.length, false);
    }

    final results = <bool>[];
    for (var i = 0; i < messages.length; i++) {
      results. add(await verify(messages[i], signatures[i], publicKey));
    }
    return results;
  }

  // ─────────────────────────────────────────────────────────
  // Utility Functions
  // ─────────────────────────────────────────────────────────

  /// Extract public key from secret key
  static Future<Uint8List> extractPublicKey(SecureKey secretKey) async {
    final sodium = await SodiumLoader.sodium;
    // Public key is last 32 bytes of Ed25519 secret key
    final skBytes = secretKey.extractBytes();
    final pk = Uint8List. fromList(skBytes.sublist(32, 64));
    // Zero the extracted bytes
    for (var i = 0; i < skBytes.length; i++) {
      skBytes[i] = 0;
    }
    return pk;
  }

  static bool _validateInputs(Uint8List signature, Uint8List publicKey) {
    if (signature.length != signatureBytes) {
      return false;
    }
    if (publicKey.length != publicKeyBytes) {
      return false;
    }
    return true;
  }
}