// CSPRNG utilities
import 'dart:typed_data';

import 'package:sodium_libs/sodium_libs.dart';

import '../bridge/sodium_loader.dart';

/// ============================================================
/// Cryptographic Random Generator
/// ============================================================
/// Provides cryptographically secure random data using
/// libsodium's randombytes (ChaCha20-based CSPRNG).
///
/// Security Properties:
/// • 256-bit security level
/// • Backtracking resistant
/// • Prediction resistant
/// • Uses OS entropy sources
///
/// Use for:
/// • Key generation
/// • Nonces and IVs
/// • Session tokens
/// • Any security-critical randomness
/// ============================================================
final class RandomGenerator {
  RandomGenerator._();

  /// Maximum single generation size (1MB)
  static const int maxSize = 1024 * 1024;

  /// Generate random bytes
  static Future<Uint8List> bytes(int length) async {
    _validateLength(length);
    final sodium = await SodiumLoader.sodium;
    return sodium.randombytes.buf(length);
  }

  /// Generate random bytes synchronously (requires prior init)
  static Uint8List bytesSync(int length) {
    _validateLength(length);
    return SodiumLoader.sodiumSync.randombytes.buf(length);
  }

  /// Fill existing buffer with random bytes
  static Future<void> fill(Uint8List buffer) async {
    final sodium = await SodiumLoader.sodium;
    final random = sodium.randombytes.buf(buffer.length);
    for (var i = 0; i < buffer.length; i++) {
      buffer[i] = random[i];
    }
  }

  /// Generate random 32-bit unsigned integer
  static Future<int> uint32() async {
    final sodium = await SodiumLoader.sodium;
    return sodium.randombytes.random();
  }

  /// Generate random integer in range [0, upperBound)
  static Future<int> uniform(int upperBound) async {
    if (upperBound <= 0) {
      throw ArgumentError('Upper bound must be positive: $upperBound');
    }
    final sodium = await SodiumLoader.sodium;
    return sodium.randombytes.uniform(upperBound);
  }

  /// Generate random integer in range [min, max]
  static Future<int> range(int min, int max) async {
    if (min >= max) {
      throw ArgumentError('min must be less than max: $min >= $max');
    }
    return min + await uniform(max - min + 1);
  }

  /// Generate random nonce for AEAD encryption
  static Future<Uint8List> nonce({int length = 24}) async {
    return bytes(length);
  }

  /// Generate random salt for password hashing
  static Future<Uint8List> salt({int length = 16}) async {
    return bytes(length);
  }

  /// Generate random IV for symmetric encryption
  static Future<Uint8List> iv({int length = 12}) async {
    return bytes(length);
  }

  /// Generate random session ID (32 bytes, hex encoded)
  static Future<String> sessionId() async {
    final data = await bytes(32);
    return _bytesToHex(data);
  }

  /// Generate random device ID (16 bytes, hex encoded)
  static Future<String> deviceId() async {
    final data = await bytes(16);
    return _bytesToHex(data);
  }

  /// Generate random message ID (16 bytes, hex encoded)
  static Future<String> messageId() async {
    final data = await bytes(16);
    return _bytesToHex(data);
  }

  /// Generate UUID v4
  static Future<String> uuid() async {
    final data = await bytes(16);

    // Set version (4) and variant (RFC 4122)
    data[6] = (data[6] & 0x0f) | 0x40;
    data[8] = (data[8] & 0x3f) | 0x80;

    final hex = _bytesToHex(data);
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}';
  }

  /// Generate secure random key ID
  static Future<int> keyId() async {
    return uint32();
  }

  /// Generate registration ID (Signal protocol)
  static Future<int> registrationId() async {
    // 14-bit random value (0 to 16380)
    return await uniform(16380) + 1;
  }

  /// Convert bytes to hex string
  static String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Validate length parameter
  static void _validateLength(int length) {
    if (length <= 0) {
      throw ArgumentError('Length must be positive:  $length');
    }
    if (length > maxSize) {
      throw ArgumentError('Length exceeds maximum ($maxSize): $length');
    }
  }
}
