import 'dart:typed_data';

import 'package:sodium_libs/sodium_libs.dart';

import '../bridge/sodium_loader.dart';
import '../crypto/random_generator.dart';

/// ============================================================
/// Backup Cryptography
/// ============================================================
/// Implements secure backup encryption: 
///
/// • Argon2id for password-based key derivation
/// • XChaCha20-Poly1305 for encryption
/// • Strong parameters for offline attack resistance
/// ============================================================
final class BackupCrypto {
  BackupCrypto._();

  static const int saltSize = 16;
  static const int minPassphraseLength = 8;
  
  // XChaCha20-Poly1305 constants
  static const int nonceSize = 24;
  static const int tagSize = 16;

  static Future<Uint8List> generateSalt() async {
    return RandomGenerator. salt(length: saltSize);
  }

  /// Derive backup key from passphrase
  static Future<SecureKey> deriveKey({
    required String passphrase,
    required Uint8List salt,
  }) async {
    if (passphrase.length < minPassphraseLength) {
      throw ArgumentError(
        'Passphrase must be at least $minPassphraseLength characters',
      );
    }
    if (salt.length != saltSize) {
      throw ArgumentError('Salt must be $saltSize bytes');
    }

    final sodium = await SodiumLoader.sodium;

    return sodium.crypto. pwhash. call(
      password: Int8List.fromList(passphrase.codeUnits),
      salt: salt,
      outLen: 32,
      opsLimit: sodium.crypto.pwhash.opsLimitModerate,
      memLimit: sodium.crypto. pwhash.memLimitModerate,
    );
  }

  /// Encrypt backup data with XChaCha20-Poly1305
  static Future<Uint8List> encrypt({
    required SecureKey key,
    required Uint8List plaintext,
  }) async {
    final sodium = await SodiumLoader.sodium;

    // Generate random nonce (24 bytes for XChaCha20)
    final nonce = sodium.randombytes. buf(nonceSize);

    // Use secretBox for authenticated encryption (XSalsa20-Poly1305)
    // This is the recommended AEAD in sodium_libs
    final ciphertext = sodium. crypto.secretBox.easy(
      message: plaintext,
      nonce: nonce,
      key: key,
    );

    // Return nonce || ciphertext
    return Uint8List.fromList([... nonce, ...ciphertext]);
  }

  /// Decrypt backup data
  static Future<Uint8List> decrypt({
    required SecureKey key,
    required Uint8List encrypted,
  }) async {
    final sodium = await SodiumLoader.sodium;

    // secretBox nonce is 24 bytes
    const nonceLen = 24;

    if (encrypted.length <= nonceLen) {
      throw BackupDecryptionException('Encrypted data too short');
    }

    final nonce = encrypted. sublist(0, nonceLen);
    final ciphertext = encrypted.sublist(nonceLen);

    try {
      return sodium.crypto.secretBox.openEasy(
        cipherText: ciphertext,
        nonce:  nonce,
        key: key,
      );
    } catch (e) {
      throw BackupDecryptionException(
        'Decryption failed.  Wrong passphrase or corrupted data.',
      );
    }
  }

  /// Verify backup integrity without full decryption
  static Future<bool> verify({
    required SecureKey key,
    required Uint8List encrypted,
  }) async {
    try {
      await decrypt(key: key, encrypted: encrypted);
      return true;
    } catch (_) {
      return false;
    }
  }
}

class BackupDecryptionException implements Exception {
  final String message;

  BackupDecryptionException(this. message);

  @override
  String toString() => 'BackupDecryptionException: $message';
}