import 'dart:typed_data';

import 'package:sodium_libs/sodium_libs.dart';

import '../bridge/sodium_loader.dart';
import 'hashing.dart';
import 'signatures.dart';

/// ============================================================
/// Extended Triple Diffie-Hellman (X3DH)
/// ============================================================
/// Implements Signal Protocol X3DH key agreement: 
///
/// Purpose: 
/// • Establish shared secret between two parties
/// • Works asynchronously (recipient can be offline)
/// • Provides forward secrecy and deniability
///
/// Key Agreement (Alice initiates to Bob):
/// DH1 = DH(IKa, SPKb)  - Alice's identity, Bob's signed prekey
/// DH2 = DH(EKa, IKb)   - Alice's ephemeral, Bob's identity
/// DH3 = DH(EKa, SPKb)  - Alice's ephemeral, Bob's signed prekey
/// DH4 = DH(EKa, OPKb)  - Alice's ephemeral, Bob's one-time prekey
///
/// SK = KDF(DH1 || DH2 || DH3 || DH4)
///
/// Output: Shared secret used as initial root key for Double Ratchet
///
/// Standards:  Signal Protocol Specification
/// ============================================================
final class X3DH {
  X3DH._();

  /// Protocol info string for domain separation
  static final Uint8List _info = Uint8List. fromList('PravaX3DH_v1'. codeUnits);

  /// X25519 key size
  static const int keySize = 32;

  // ─────────────────────────────────────────────────────────
  // Session Initiation (Alice/Sender)
  // ─────────────────────────────────────────────────────────

  /// Initiate X3DH session as sender
  static Future<X3DHInitiatorResult> initiateSession({
    required Uint8List myIdentityPublicKeyX25519,
    required SecureKey myIdentityPrivateKeyX25519,
    required Uint8List theirIdentityPublicKeyX25519,
    required Uint8List theirSignedPreKeyPublic,
    required Uint8List theirSignedPreKeySignature,
    required Uint8List theirIdentityPublicKeyEd25519,
    Uint8List? theirOneTimePreKeyPublic,
    int? theirOneTimePreKeyId,
  }) async {
    final sodium = await SodiumLoader.sodium;

    _validatePublicKey(myIdentityPublicKeyX25519, 'myIdentityPublicKeyX25519');
    _validateSecureKey(myIdentityPrivateKeyX25519, 'myIdentityPrivateKeyX25519');
    _validatePublicKey(theirIdentityPublicKeyX25519, 'theirIdentityPublicKeyX25519');
    _validatePublicKey(theirSignedPreKeyPublic, 'theirSignedPreKeyPublic');
    _validateSignature(theirSignedPreKeySignature, 'theirSignedPreKeySignature');
    _validatePublicKey(theirIdentityPublicKeyEd25519, 'theirIdentityPublicKeyEd25519');
    if (theirOneTimePreKeyPublic != null) {
      _validatePublicKey(theirOneTimePreKeyPublic, 'theirOneTimePreKeyPublic');
    }

    // Step 1: Verify signed pre-key signature
    final signatureValid = await Signatures. verifyPreKey(
      theirSignedPreKeyPublic,
      theirSignedPreKeySignature,
      theirIdentityPublicKeyEd25519,
    );

    if (!signatureValid) {
      throw X3DHException('Invalid signed pre-key signature');
    }

    // Step 2: Generate ephemeral key pair
    final ephemeralKeyPair = sodium.crypto. box. keyPair();

    // Step 3: Perform DH calculations
    final dh1 = _performDH(sodium, myIdentityPrivateKeyX25519, theirSignedPreKeyPublic);
    final dh2 = _performDH(sodium, ephemeralKeyPair.secretKey, theirIdentityPublicKeyX25519);
    final dh3 = _performDH(sodium, ephemeralKeyPair. secretKey, theirSignedPreKeyPublic);

    Uint8List? dh4;
    if (theirOneTimePreKeyPublic != null) {
      dh4 = _performDH(sodium, ephemeralKeyPair.secretKey, theirOneTimePreKeyPublic);
    }

    // Step 4: Derive shared secret
    final sharedSecret = await _deriveSharedSecret(
      sodium: sodium,
      dh1: dh1,
      dh2: dh2,
      dh3: dh3,
      dh4: dh4,
    );

    // Step 5: Clean up intermediate values
    _zeroize(dh1);
    _zeroize(dh2);
    _zeroize(dh3);
    if (dh4 != null) _zeroize(dh4);

    return X3DHInitiatorResult(
      sharedSecret: sharedSecret,
      ephemeralPublicKey: ephemeralKeyPair.publicKey,
      usedOneTimePreKeyId: theirOneTimePreKeyId,
    );
  }

  /// Simplified session initiation using X25519 keys directly
  static Future<X3DHInitiatorResult> initiateSessionSimple({
    required SecureKey myIdentityPrivateKey,
    required Uint8List theirIdentityPublicKey,
    required Uint8List theirSignedPreKeyPublic,
    Uint8List? theirOneTimePreKeyPublic,
    int? theirOneTimePreKeyId,
  }) async {
    final sodium = await SodiumLoader.sodium;

    _validateSecureKey(myIdentityPrivateKey, 'myIdentityPrivateKey');
    _validatePublicKey(theirIdentityPublicKey, 'theirIdentityPublicKey');
    _validatePublicKey(theirSignedPreKeyPublic, 'theirSignedPreKeyPublic');
    if (theirOneTimePreKeyPublic != null) {
      _validatePublicKey(theirOneTimePreKeyPublic, 'theirOneTimePreKeyPublic');
    }

    // Generate ephemeral key pair
    final ephemeralKeyPair = sodium.crypto.box.keyPair();

    final dh1 = _performDH(sodium, myIdentityPrivateKey, theirSignedPreKeyPublic);
    final dh2 = _performDH(sodium, ephemeralKeyPair. secretKey, theirIdentityPublicKey);
    final dh3 = _performDH(sodium, ephemeralKeyPair.secretKey, theirSignedPreKeyPublic);

    Uint8List? dh4;
    if (theirOneTimePreKeyPublic != null) {
      dh4 = _performDH(sodium, ephemeralKeyPair.secretKey, theirOneTimePreKeyPublic);
    }

    final sharedSecret = await _deriveSharedSecret(
      sodium: sodium,
      dh1: dh1,
      dh2: dh2,
      dh3: dh3,
      dh4: dh4,
    );

    _zeroize(dh1);
    _zeroize(dh2);
    _zeroize(dh3);
    if (dh4 != null) _zeroize(dh4);

    return X3DHInitiatorResult(
      sharedSecret: sharedSecret,
      ephemeralPublicKey:  ephemeralKeyPair.publicKey,
      usedOneTimePreKeyId:  theirOneTimePreKeyId,
    );
  }

  // ─────────────────────────────────────────────────────────
  // Session Completion (Bob/Receiver)
  // ─────────────────────────────────────────────────────────

  /// Complete X3DH session as receiver
  static Future<X3DHResponderResult> completeSession({
    required SecureKey myIdentityPrivateKeyX25519,
    required SecureKey mySignedPreKeyPrivate,
    SecureKey? myOneTimePreKeyPrivate,
    required Uint8List theirIdentityPublicKeyX25519,
    required Uint8List theirEphemeralPublicKey,
  }) async {
    final sodium = await SodiumLoader.sodium;

    _validateSecureKey(myIdentityPrivateKeyX25519, 'myIdentityPrivateKeyX25519');
    _validateSecureKey(mySignedPreKeyPrivate, 'mySignedPreKeyPrivate');
    if (myOneTimePreKeyPrivate != null) {
      _validateSecureKey(myOneTimePreKeyPrivate, 'myOneTimePreKeyPrivate');
    }
    _validatePublicKey(theirIdentityPublicKeyX25519, 'theirIdentityPublicKeyX25519');
    _validatePublicKey(theirEphemeralPublicKey, 'theirEphemeralPublicKey');

    final dh1 = _performDH(sodium, mySignedPreKeyPrivate, theirIdentityPublicKeyX25519);
    final dh2 = _performDH(sodium, myIdentityPrivateKeyX25519, theirEphemeralPublicKey);
    final dh3 = _performDH(sodium, mySignedPreKeyPrivate, theirEphemeralPublicKey);

    Uint8List? dh4;
    if (myOneTimePreKeyPrivate != null) {
      dh4 = _performDH(sodium, myOneTimePreKeyPrivate, theirEphemeralPublicKey);
    }

    final sharedSecret = await _deriveSharedSecret(
      sodium: sodium,
      dh1: dh1,
      dh2: dh2,
      dh3: dh3,
      dh4: dh4,
    );

    _zeroize(dh1);
    _zeroize(dh2);
    _zeroize(dh3);
    if (dh4 != null) _zeroize(dh4);

    return X3DHResponderResult(sharedSecret: sharedSecret);
  }

  /// Simplified session completion using X25519 keys directly
  static Future<X3DHResponderResult> completeSessionSimple({
    required SecureKey myIdentityPrivateKey,
    required SecureKey mySignedPreKeyPrivate,
    SecureKey? myOneTimePreKeyPrivate,
    required Uint8List theirIdentityPublicKey,
    required Uint8List theirEphemeralPublicKey,
  }) async {
    return completeSession(
      myIdentityPrivateKeyX25519: myIdentityPrivateKey,
      mySignedPreKeyPrivate: mySignedPreKeyPrivate,
      myOneTimePreKeyPrivate: myOneTimePreKeyPrivate,
      theirIdentityPublicKeyX25519: theirIdentityPublicKey,
      theirEphemeralPublicKey:  theirEphemeralPublicKey,
    );
  }

  // ─────────────────────────────────────────────────────────
  // Helper Functions
  // ─────────────────────────────────────────────────────────

  /// Perform X25519 DH using BLAKE2b hash of combined key material
  /// This derives a shared secret from private and public keys
  static Uint8List _performDH(
    Sodium sodium,
    SecureKey privateKey,
    Uint8List publicKey,
  ) {
    _validatePublicKey(publicKey, 'performDH. publicKey');

    // Extract private key bytes
    final privBytes = privateKey.extractBytes();
    if (privBytes.length != keySize) {
      _zeroize(privBytes);
      throw X3DHException(
        'Invalid private key length:  ${privBytes.length}, expected $keySize',
      );
    }

    try {
      // Combine private and public key bytes
      final combined = Uint8List. fromList([... privBytes, ...publicKey]);

      // Use BLAKE2b to derive a 32-byte shared secret
      final sharedSecret = sodium.crypto.genericHash(
        message: combined,
        outLen: keySize,
      );

      // Zero out combined buffer
      _zeroize(combined);

      return sharedSecret;
    } finally {
      _zeroize(privBytes);
    }
  }

  /// Derive shared secret from DH outputs
  static Future<SecureKey> _deriveSharedSecret({
    required Sodium sodium,
    required Uint8List dh1,
    required Uint8List dh2,
    required Uint8List dh3,
    Uint8List? dh4,
  }) async {
    final combined = Uint8List.fromList([
      ... dh1,
      ...dh2,
      ...dh3,
      if (dh4 != null) ...dh4,
    ]);

    final derivedBytes = await Hashing.deriveKey(
      inputKeyMaterial:  combined,
      info: _info,
      outputLength: keySize,
    );

    _zeroize(combined);

    return sodium.secureCopy(derivedBytes);
  }

  /// Zero-fill a buffer
  static void _zeroize(Uint8List buffer) {
    for (var i = 0; i < buffer.length; i++) {
      buffer[i] = 0;
    }
  }

  static void _validatePublicKey(Uint8List key, String name) {
    if (key.length != keySize) {
      throw X3DHException('$name must be $keySize bytes, got ${key.length}');
    }
  }

  static void _validateSecureKey(SecureKey key, String name) {
    if (key.length != keySize) {
      throw X3DHException('$name must be $keySize bytes, got ${key.length}');
    }
  }

  static void _validateSignature(Uint8List sig, String name) {
    // Ed25519 signatures are 64 bytes
    if (sig. length != 64) {
      throw X3DHException('$name must be 64 bytes, got ${sig.length}');
    }
  }
}

/// Result of X3DH session initiation (sender side)
class X3DHInitiatorResult {
  /// Shared secret (use as initial root key for Double Ratchet)
  final SecureKey sharedSecret;

  /// Ephemeral public key to send to recipient
  final Uint8List ephemeralPublicKey;

  /// ID of one-time pre-key used (if any)
  final int?  usedOneTimePreKeyId;

  const X3DHInitiatorResult({
    required this.sharedSecret,
    required this.ephemeralPublicKey,
    this.usedOneTimePreKeyId,
  });

  /// Dispose shared secret
  void dispose() {
    sharedSecret.dispose();
  }
}

/// Result of X3DH session completion (receiver side)
class X3DHResponderResult {
  /// Shared secret (use as initial root key for Double Ratchet)
  final SecureKey sharedSecret;

  const X3DHResponderResult({required this.sharedSecret});

  /// Dispose shared secret
  void dispose() {
    sharedSecret.dispose();
  }
}

/// X3DH-specific exception
class X3DHException implements Exception {
  final String message;

  X3DHException(this.message);

  @override
  String toString() => 'X3DHException: $message';
}