// Packet padding
import 'dart:typed_data';

import '../crypto/random_generator.dart';

/// ============================================================
/// Packet Padding
/// ============================================================
/// Implements PKCS#7-style padding with random fill:
///
/// • Consistent packet sizes
/// • Random padding content
/// • Prevents size-based analysis
/// ============================================================
final class PacketPadding {
  PacketPadding._();

  /// Standard packet sizes
  static const List<int> standardSizes = [64, 128, 256, 512, 1024, 2048, 4096];

  /// Pad to next standard size
  static Future<Uint8List> padToStandard(Uint8List data) async {
    // Find next standard size
    int targetSize = standardSizes.last;
    for (final size in standardSizes) {
      if (data.length + 2 <= size) {
        targetSize = size;
        break;
      }
    }

    return pad(data, targetSize);
  }

  /// Pad to specific size
  static Future<Uint8List> pad(Uint8List data, int targetSize) async {
    if (data. length + 2 > targetSize) {
      throw ArgumentError('Data too large for target size');
    }

    final paddingLength = targetSize - data.length - 2;
    final padding = await RandomGenerator.bytes(paddingLength);

    final result = Uint8List(targetSize);

    // Store length (2 bytes, big-endian)
    result[0] = (data. length >> 8) & 0xFF;
    result[1] = data.length & 0xFF;

    // Copy data
    result.setRange(2, 2 + data. length, data);

    // Copy random padding
    result. setRange(2 + data.length, targetSize, padding);

    return result;
  }

  /// Remove padding
  static Uint8List unpad(Uint8List padded) {
    if (padded.length < 2) {
      throw ArgumentError('Padded data too short');
    }

    final length = (padded[0] << 8) | padded[1];

    if (length < 0 || length > padded.length - 2) {
      throw ArgumentError('Invalid padding');
    }

    return padded.sublist(2, 2 + length);
  }

  /// Get overhead for a given data size
  static int getOverhead(int dataSize) {
    for (final size in standardSizes) {
      if (dataSize + 2 <= size) {
        return size - dataSize;
      }
    }
    return standardSizes.last - dataSize;
  }
}