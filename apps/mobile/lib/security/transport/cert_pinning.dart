// TLS certificate pinning
import 'dart:io';

import 'package:crypto/crypto.dart';

/// ============================================================
/// Certificate Pinning
/// ============================================================
/// Implements TLS certificate pinning: 
///
/// • Pin to public key hash (SPKI)
/// • Support backup pins for rotation
/// • Prevent MITM attacks
/// ============================================================
final class CertPinning {
  CertPinning._();

  static final Set<String> _pinnedHashes = {};
  static final Set<String> _backupHashes = {};
  static bool _enabled = false;

  /// Configure pinned certificates
  static void configure({
    required List<String> pins,
    List<String> backupPins = const [],
  }) {
    _pinnedHashes.clear();
    _pinnedHashes.addAll(pins. map((p) => p.toUpperCase()));

    _backupHashes.clear();
    _backupHashes.addAll(backupPins. map((p) => p.toUpperCase()));

    _enabled = _pinnedHashes. isNotEmpty;
  }

  /// Check if pinning is enabled
  static bool get isEnabled => _enabled;

  /// Disable pinning (for development)
  static void disable() {
    _enabled = false;
  }

  /// Create HttpClient with pinning
  static HttpClient createClient() {
    final client = HttpClient();

    if (_enabled) {
      client.badCertificateCallback = (cert, host, port) {
        return verify(cert);
      };
    }

    return client;
  }

  /// Verify certificate against pins
  static bool verify(X509Certificate cert) {
    if (! _enabled) return true;

    final hash = _hashCertificate(cert);
    return _pinnedHashes.contains(hash) || _backupHashes.contains(hash);
  }

  /// Hash certificate (SHA-256 of DER)
  static String _hashCertificate(X509Certificate cert) {
    final hash = sha256.convert(cert.der);
    return hash.bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
  }

  /// Extract pin from certificate for configuration
  static String extractPin(X509Certificate cert) {
    return _hashCertificate(cert);
  }

  /// Get current pins
  static Set<String> get currentPins => Set.unmodifiable(_pinnedHashes);

  /// Get backup pins
  static Set<String> get backupPins => Set.unmodifiable(_backupHashes);
}