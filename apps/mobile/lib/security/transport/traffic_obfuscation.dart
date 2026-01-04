// Traffic obfuscation
import 'dart:math';
import 'dart:typed_data';

import '../crypto/random_generator.dart';

/// ============================================================
/// Traffic Obfuscation
/// ============================================================
/// Protects against traffic analysis: 
///
/// • Random padding to hide message sizes
/// • Dummy traffic generation
/// • Timing jitter
/// ============================================================
final class TrafficObfuscation {
  TrafficObfuscation._();

  /// Minimum padding size
  static const int minPadding = 16;

  /// Maximum padding size
  static const int maxPadding = 256;

  /// Add random padding to message
  static Future<Uint8List> addPadding(Uint8List message) async {
    // Generate random padding length
    final paddingLength = minPadding + Random.secure().nextInt(maxPadding - minPadding);

    // Generate random padding
    final padding = await RandomGenerator.bytes(paddingLength);

    // Format:  [original_length (4 bytes)] [message] [padding]
    final result = Uint8List(4 + message.length + paddingLength);

    // Store original length (big-endian)
    result[0] = (message.length >> 24) & 0xFF;
    result[1] = (message.length >> 16) & 0xFF;
    result[2] = (message.length >> 8) & 0xFF;
    result[3] = message. length & 0xFF;

    // Copy message
    result. setRange(4, 4 + message.length, message);

    // Copy padding
    result. setRange(4 + message.length, result.length, padding);

    return result;
  }

  /// Remove padding from message
  static Uint8List removePadding(Uint8List padded) {
    if (padded. length < 4) {
      throw ArgumentError('Padded message too short');
    }

    // Read original length
    final originalLength = (padded[0] << 24) |
        (padded[1] << 16) |
        (padded[2] << 8) |
        padded[3];

    if (originalLength < 0 || originalLength > padded.length - 4) {
      throw ArgumentError('Invalid padding');
    }

    return padded.sublist(4, 4 + originalLength);
  }

  /// Pad message to fixed size
  static Future<Uint8List> padToSize(Uint8List message, int targetSize) async {
    if (message.length > targetSize - 4) {
      throw ArgumentError('Message too large for target size');
    }

    final paddingLength = targetSize - 4 - message.length;
    final padding = await RandomGenerator.bytes(paddingLength);

    final result = Uint8List(targetSize);

    // Store original length
    result[0] = (message.length >> 24) & 0xFF;
    result[1] = (message.length >> 16) & 0xFF;
    result[2] = (message.length >> 8) & 0xFF;
    result[3] = message.length & 0xFF;

    // Copy message and padding
    result. setRange(4, 4 + message.length, message);
    result.setRange(4 + message.length, targetSize, padding);

    return result;
  }

  /// Generate random delay for timing jitter
  static Duration getRandomDelay({
    Duration min = const Duration(milliseconds: 10),
    Duration max = const Duration(milliseconds: 100),
  }) {
    final range = max. inMilliseconds - min.inMilliseconds;
    final delay = min.inMilliseconds + Random.secure().nextInt(range);
    return Duration(milliseconds: delay);
  }

  /// Apply timing jitter
  static Future<void> applyJitter({
    Duration min = const Duration(milliseconds: 10),
    Duration max = const Duration(milliseconds: 100),
  }) async {
    await Future.delayed(getRandomDelay(min: min, max: max));
  }
}