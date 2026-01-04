// Metadata stripping
import 'dart:typed_data';

/// ============================================================
/// Metadata Strip
/// ============================================================
/// Removes identifying metadata from media:
///
/// • EXIF data from images
/// • GPS coordinates
/// • Device information
/// • Timestamps
/// ============================================================
final class MetadataStrip {
  MetadataStrip._();

  /// Strip metadata from image
  static Uint8List stripImage(Uint8List imageData) {
    if (imageData.length < 2) return imageData;

    // JPEG
    if (imageData[0] == 0xFF && imageData[1] == 0xD8) {
      return _stripJpeg(imageData);
    }

    // PNG
    if (imageData[0] == 137 && imageData[1] == 80) {
      return _stripPng(imageData);
    }

    return imageData;
  }

  /// Strip JPEG EXIF data
  static Uint8List _stripJpeg(Uint8List data) {
    final result = <int>[];
    var i = 0;

    // Add SOI marker
    result.addAll([0xFF, 0xD8]);
    i += 2;

    while (i < data. length - 1) {
      if (data[i] != 0xFF) {
        i++;
        continue;
      }

      final marker = data[i + 1];

      // Skip APP1-APP15 (EXIF, etc.)
      if (marker >= 0xE1 && marker <= 0xEF) {
        if (i + 3 < data.length) {
          final length = (data[i + 2] << 8) | data[i + 3];
          i += 2 + length;
          continue;
        }
      }

      // Keep APP0 (JFIF)
      if (marker == 0xE0) {
        if (i + 3 < data.length) {
          final length = (data[i + 2] << 8) | data[i + 3];
          result.addAll(data.sublist(i, i + 2 + length));
          i += 2 + length;
          continue;
        }
      }

      // Start of Scan - copy rest
      if (marker == 0xDA) {
        result.addAll(data.sublist(i));
        break;
      }

      // End of Image
      if (marker == 0xD9) {
        result.addAll([0xFF, 0xD9]);
        break;
      }

      // Copy other markers
      if (i + 3 < data.length) {
        final length = (data[i + 2] << 8) | data[i + 3];
        result.addAll(data.sublist(i, i + 2 + length));
        i += 2 + length;
      } else {
        i++;
      }
    }

    return Uint8List. fromList(result);
  }

  /// Strip PNG metadata chunks
  static Uint8List _stripPng(Uint8List data) {
    const signature = [137, 80, 78, 71, 13, 10, 26, 10];

    // Verify signature
    for (var i = 0; i < 8; i++) {
      if (data[i] != signature[i]) return data;
    }

    final result = <int>[];
    result.addAll(signature);

    var i = 8;
    while (i < data.length - 12) {
      final length = (data[i] << 24) |
          (data[i + 1] << 16) |
          (data[i + 2] << 8) |
          data[i + 3];

      final type = String.fromCharCodes(data.sublist(i + 4, i + 8));

      // Keep only critical chunks
      const critical = ['IHDR', 'PLTE', 'IDAT', 'IEND'];
      if (critical. contains(type)) {
        result.addAll(data.sublist(i, i + 12 + length));
      }

      i += 12 + length;
    }

    return Uint8List.fromList(result);
  }

  /// Check if image has GPS data
  static bool hasGpsData(Uint8List data) {
    // Simple check for GPS marker
    const gpsMarker = [0x47, 0x50, 0x53]; // "GPS"
    
    for (var i = 0; i < data.length - 3; i++) {
      if (data[i] == gpsMarker[0] &&
          data[i + 1] == gpsMarker[1] &&
          data[i + 2] == gpsMarker[2]) {
        return true;
      }
    }
    return false;
  }

  /// Get image type
  static String?  getImageType(Uint8List data) {
    if (data.length < 2) return null;

    if (data[0] == 0xFF && data[1] == 0xD8) return 'jpeg';
    if (data[0] == 137 && data[1] == 80) return 'png';
    if (data[0] == 0x47 && data[1] == 0x49) return 'gif';
    if (data[0] == 0x52 && data[1] == 0x49) return 'webp';

    return null;
  }
}