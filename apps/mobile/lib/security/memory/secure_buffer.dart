// Native secure buffer
import 'dart:ffi';
import 'dart:typed_data';

import '../bridge/memory_allocator.dart';

/// ============================================================
/// SecureBuffer - Anti-Forensics Memory Container
/// ============================================================
/// Stores sensitive data in native memory: 
///
/// Security Guarantees:
/// • No Dart GC access (prevents memory copies)
/// • Explicit zeroization on disposal
/// • Use-after-dispose detection
/// • Bounds checking
///
/// Use for:
/// • Private keys
/// • Session secrets
/// • Decrypted plaintext
/// • Any sensitive cryptographic material
/// ============================================================
final class SecureBuffer {
  Pointer<Uint8>? _ptr;
  final int length;
  bool _disposed = false;
  final String? _label;

  /// Create secure buffer from bytes (zeros source)
  SecureBuffer(Uint8List bytes, {String? label})
      : length = bytes.length,
        _label = label {
    _ptr = MemoryAllocator.allocate(bytes.length, label: label);

    // Copy bytes into native memory
    for (var i = 0; i < bytes. length; i++) {
      _ptr![i] = bytes[i];
    }

    // Zero source bytes
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = 0;
    }
  }

  /// Allocate empty secure buffer
  SecureBuffer.allocate(this.length, {String? label}) : _label = label {
    _ptr = MemoryAllocator.allocate(length, label: label);
  }

  /// Create from pointer (takes ownership)
  SecureBuffer.fromPointer(Pointer<Uint8> ptr, this.length, {String? label})
      : _ptr = ptr,
        _label = label;

  /// Check if buffer is valid
  bool get isValid => ! _disposed && _ptr != null;

  /// Check if disposed
  bool get isDisposed => _disposed;

  /// Get bytes (creates GC-managed copy - use sparingly)
  Uint8List get bytes {
    _checkDisposed();
    return _ptr!.asTypedList(length);
  }

  /// Get copy of bytes (safer, creates new buffer)
  Uint8List toBytes() {
    _checkDisposed();
    return Uint8List.fromList(bytes);
  }

  /// Get byte at index
  int operator [](int index) {
    _checkDisposed();
    _checkBounds(index);
    return _ptr![index];
  }

  /// Set byte at index
  void operator []=(int index, int value) {
    _checkDisposed();
    _checkBounds(index);
    _ptr![index] = value;
  }

  /// Copy to another secure buffer
  void copyTo(SecureBuffer other) {
    _checkDisposed();
    other._checkDisposed();

    if (length != other.length) {
      throw ArgumentError('Buffer size mismatch:  $length != ${other.length}');
    }

    for (var i = 0; i < length; i++) {
      other._ptr![i] = _ptr![i];
    }
  }

  /// Constant-time equality comparison
  bool equals(SecureBuffer other) {
    _checkDisposed();
    other._checkDisposed();

    if (length != other. length) return false;

    var result = 0;
    for (var i = 0; i < length; i++) {
      result |= _ptr![i] ^ other._ptr![i];
    }
    return result == 0;
  }

  /// Fill with zeros (without disposing)
  void zero() {
    _checkDisposed();
    for (var i = 0; i < length; i++) {
      _ptr![i] = 0;
    }
  }

  /// Dispose and zero memory
  void dispose() {
    if (_disposed) return;

    if (_ptr != null) {
      MemoryAllocator. freeSecure(_ptr!, length);
      _ptr = null;
    }

    _disposed = true;
  }

  void _checkDisposed() {
    if (_disposed) {
      throw StateError(
        'SecureBuffer disposed${_label != null ? ' ($_label)' : ''}',
      );
    }
  }

  void _checkBounds(int index) {
    if (index < 0 || index >= length) {
      throw RangeError.index(index, this, 'index', null, length);
    }
  }

  @override
  String toString() => 'SecureBuffer(length: $length, disposed: $_disposed'
      '${_label != null ? ', label: $_label' : ''})';
}

/// Extension for scoped usage
extension SecureBufferScope on SecureBuffer {
  /// Execute operation and auto-dispose
  T use<T>(T Function(SecureBuffer buffer) operation) {
    try {
      return operation(this);
    } finally {
      dispose();
    }
  }

  /// Execute async operation and auto-dispose
  Future<T> useAsync<T>(
    Future<T> Function(SecureBuffer buffer) operation,
  ) async {
    try {
      return await operation(this);
    } finally {
      dispose();
    }
  }
}