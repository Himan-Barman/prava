// Contact hashing
import 'dart:typed_data';

import '../bridge/sodium_loader.dart';

/// ============================================================
/// Contact Hash
/// ============================================================
/// Privacy-preserving contact discovery:
///
/// • Hash phone numbers before sending to server
/// • Truncated hashes for plausible deniability
/// • Salt rotation for forward secrecy
/// ============================================================
final class ContactHash {
  ContactHash._();

  /// Truncated hash length (bytes)
  static const int hashLength = 10;

  /// Hash a phone number
  static Future<Uint8List> hashPhoneNumber(
    String phoneNumber, {
    required Uint8List salt,
  }) async {
    final sodium = await SodiumLoader.sodium;

    // Normalize
    final normalized = _normalize(phoneNumber);
    final input = Uint8List.fromList(normalized.codeUnits);

    // Hash with salt
    final fullHash = sodium.crypto. genericHash(
      message:  Uint8List.fromList([... salt, ...input]),
      outLen:  32,
    );

    // Truncate for privacy
    return fullHash.sublist(0, hashLength);
  }

  /// Hash batch of phone numbers
  static Future<Map<String, Uint8List>> hashBatch(
    List<String> phoneNumbers, {
    required Uint8List salt,
  }) async {
    final results = <String, Uint8List>{};

    for (final number in phoneNumbers) {
      results[number] = await hashPhoneNumber(number, salt: salt);
    }

    return results;
  }

  /// Generate salt for contact discovery
  static Future<Uint8List> generateSalt() async {
    final sodium = await SodiumLoader.sodium;
    return sodium.randombytes. buf(32);
  }

  /// Normalize phone number
  static String _normalize(String number) {
    // Remove all non-digit characters except +
    final cleaned = number. replaceAll(RegExp(r'[^\d+]'), '');

    // Ensure E. 164 format
    if (cleaned.startsWith('+')) {
      return cleaned;
    } else if (cleaned.length == 10) {
      return '+1$cleaned'; // Assume US
    }

    return '+$cleaned';
  }

  /// Convert hash to hex string
  static String hashToHex(Uint8List hash) {
    return hash.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}