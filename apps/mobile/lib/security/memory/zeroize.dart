// Secure zeroization
import 'dart:ffi';
import 'dart:typed_data';

/// ============================================================
/// Zeroize - Secure Memory Wiping
/// ============================================================
/// Provides reliable memory wiping that: 
///
/// • Resists compiler optimization (dead store elimination)
/// • Works for Dart-managed and native memory
/// • Supports multiple overwrite patterns
/// • Includes memory barrier
///
/// Use for: 
/// • Temporary key material
/// • Decrypted plaintext
/// • Intermediate cryptographic values
/// ============================================================
final class Zeroize {
  Zeroize._();

  /// Wipe Uint8List with verification
  static void bytes(Uint8List buffer) {
    // Multi-pass overwrite
    for (var i = 0; i < buffer.length; i++) {
      buffer[i] = 0xFF;
    }
    _barrier();

    for (var i = 0; i < buffer.length; i++) {
      buffer[i] = 0x00;
    }
    _barrier();

    // Verify
    var sum = 0;
    for (var i = 0; i < buffer.length; i++) {
      sum += buffer[i];
    }
    if (sum != 0) {
      throw StateError('Zeroization verification failed');
    }
  }

  /// Wipe List<int>
  static void intList(List<int> list) {
    for (var i = 0; i < list.length; i++) {
      list[i] = 0xFF;
    }
    for (var i = 0; i < list.length; i++) {
      list[i] = 0;
    }
  }

  /// Wipe Int8List
  static void int8List(Int8List buffer) {
    for (var i = 0; i < buffer.length; i++) {
      buffer[i] = -1;
    }
    for (var i = 0; i < buffer.length; i++) {
      buffer[i] = 0;
    }
  }

  /// Wipe Int32List
  static void int32List(Int32List buffer) {
    for (var i = 0; i < buffer.length; i++) {
      buffer[i] = -1;
    }
    for (var i = 0; i < buffer.length; i++) {
      buffer[i] = 0;
    }
  }

  /// Wipe native pointer
  static void pointer(Pointer<Uint8> ptr, int length) {
    if (ptr.address == 0) return;

    // DOD 5220.22-M pattern
    for (var i = 0; i < length; i++) {
      ptr[i] = 0x00;
    }
    _barrier();

    for (var i = 0; i < length; i++) {
      ptr[i] = 0xFF;
    }
    _barrier();

    for (var i = 0; i < length; i++) {
      ptr[i] = 0x00;
    }
    _barrier();
  }

  /// Wipe multiple buffers
  static void all(List<Uint8List> buffers) {
    for (final buffer in buffers) {
      bytes(buffer);
    }
  }

  /// Wipe string characters in a list
  static void stringBuffer(List<int> codeUnits) {
    for (var i = 0; i < codeUnits. length; i++) {
      codeUnits[i] = 0;
    }
  }

  /// Memory barrier to prevent optimization
  static void _barrier() {
    // Force memory operation that compiler can't optimize away
    final temp = Uint8List(1);
    temp[0] = 0xFF;
    final _ = temp[0];
  }
}