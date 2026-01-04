// Protected string
import 'dart:convert';
import 'dart:typed_data';

import 'secure_buffer.dart';

/// ============================================================
/// ProtectedString - Secure String Container
/// ============================================================
/// Stores sensitive strings in native memory: 
///
/// Use for:
/// • Passwords
/// • PINs
/// • Recovery phrases
/// • API keys
///
/// Features:
/// • Native memory storage
/// • Controlled reveal
/// • Length obfuscation option
/// ============================================================
final class ProtectedString {
  final SecureBuffer _buffer;
  final int _actualLength;
  bool _disposed = false;

  /// Create protected string
  ProtectedString(String value)
      : _actualLength = utf8.encode(value).length,
        _buffer = SecureBuffer(
          Uint8List.fromList(utf8.encode(value)),
          label: 'ProtectedString',
        );

  /// Create with length padding (hides actual length)
  ProtectedString.padded(String value, {int paddedLength = 256})
      : _actualLength = utf8.encode(value).length,
        _buffer = _createPadded(value, paddedLength);

  static SecureBuffer _createPadded(String value, int paddedLength) {
    final encoded = utf8.encode(value);
    if (encoded.length > paddedLength) {
      throw ArgumentError('Value exceeds padded length');
    }

    final padded = Uint8List(paddedLength);
    for (var i = 0; i < encoded.length; i++) {
      padded[i] = encoded[i];
    }

    return SecureBuffer(padded, label:  'ProtectedString. padded');
  }

  /// Check if disposed
  bool get isDisposed => _disposed;

  /// Actual string length
  int get length => _actualLength;

  /// Reveal the string (use sparingly)
  String reveal() {
    _checkDisposed();
    return utf8.decode(_buffer.bytes. sublist(0, _actualLength));
  }

  /// Execute operation with revealed string
  T use<T>(T Function(String value) operation) {
    _checkDisposed();
    return operation(reveal());
  }

  /// Execute async operation with revealed string
  Future<T> useAsync<T>(Future<T> Function(String value) operation) async {
    _checkDisposed();
    return operation(reveal());
  }

  /// Compare with another protected string (constant-time)
  bool matches(ProtectedString other) {
    _checkDisposed();
    other._checkDisposed();

    if (_actualLength != other._actualLength) return false;

    var result = 0;
    for (var i = 0; i < _actualLength; i++) {
      result |= _buffer[i] ^ other._buffer[i];
    }
    return result == 0;
  }

  /// Dispose and zero memory
  void dispose() {
    if (_disposed) return;
    _buffer.dispose();
    _disposed = true;
  }

  void _checkDisposed() {
    if (_disposed) {
      throw StateError('ProtectedString already disposed');
    }
  }
}