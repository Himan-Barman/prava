// Native FFI bridge
import 'dart:ffi';
import 'dart:io';

/// ============================================================
/// Native API Bridge
/// ============================================================
/// FFI interface to platform-specific security features: 
///
/// Android:
/// • Android Keystore (hardware-backed keys)
/// • StrongBox (Titan M chip)
/// • TEE (Trusted Execution Environment)
///
/// iOS: 
/// • Secure Enclave (hardware key protection)
/// • Keychain Services
/// • Biometric authentication
///
/// Provides fallback for unsupported platforms. 
/// ============================================================
final class NativeApi {
  NativeApi._();

  static const String _libraryName = 'prava_security';
  static DynamicLibrary?  _library;
  static bool _initialized = false;
  static NativeCapabilities? _capabilities;

  /// Initialize native security library
  static Future<bool> initialize() async {
    if (_initialized) return _library != null;

    try {
      _library = _loadLibrary();
      if (_library != null) {
        _capabilities = await _detectCapabilities();
      }
      _initialized = true;
      return _library != null;
    } catch (e) {
      _initialized = true;
      return false;
    }
  }

  /// Load platform-specific library
  static DynamicLibrary?  _loadLibrary() {
    try {
      if (Platform.isAndroid) {
        return DynamicLibrary. open('lib$_libraryName. so');
      } else if (Platform. isIOS) {
        return DynamicLibrary.process();
      } else if (Platform.isMacOS) {
        return DynamicLibrary.open('lib$_libraryName.dylib');
      } else if (Platform.isLinux) {
        return DynamicLibrary.open('lib$_libraryName.so');
      } else if (Platform.isWindows) {
        return DynamicLibrary.open('$_libraryName. dll');
      }
    } catch (_) {
      // Library not available - fallback mode
    }
    return null;
  }

  /// Detect available security capabilities
  static Future<NativeCapabilities> _detectCapabilities() async {
    return NativeCapabilities(
      hasHardwareKeystore: Platform.isAndroid || Platform.isIOS,
      hasSecureEnclave: Platform.isIOS,
      hasStrongBox: Platform.isAndroid, // Requires runtime check
      hasTEE: Platform. isAndroid,
      hasHardwareRNG: true,
      hasBiometricAuth: Platform.isAndroid || Platform.isIOS,
    );
  }

  /// Check if native library is available
  static bool get isAvailable => _library != null;

  /// Get security capabilities
  static NativeCapabilities getCapabilities() {
    return _capabilities ??  const NativeCapabilities. none();
  }

  /// Generate hardware-backed key (Android Keystore / iOS Secure Enclave)
  static Future<HardwareKeyResult> generateHardwareKey({
    required String alias,
    required KeyType keyType,
    bool requireBiometric = false,
  }) async {
    if (! isAvailable) {
      return HardwareKeyResult.unsupported();
    }

    // Native implementation would call platform APIs
    // This is a placeholder for the FFI implementation
    return HardwareKeyResult.unsupported();
  }

  /// Sign data with hardware-backed key
  static Future<SignatureResult> signWithHardwareKey({
    required String alias,
    required List<int> data,
  }) async {
    if (!isAvailable) {
      return SignatureResult.unsupported();
    }

    return SignatureResult.unsupported();
  }

  /// Encrypt with hardware-backed key
  static Future<EncryptionResult> encryptWithHardwareKey({
    required String alias,
    required List<int> plaintext,
  }) async {
    if (!isAvailable) {
      return EncryptionResult. unsupported();
    }

    return EncryptionResult.unsupported();
  }

  /// Delete hardware-backed key
  static Future<bool> deleteHardwareKey(String alias) async {
    if (!isAvailable) return false;
    return false;
  }

  /// Check if hardware key exists
  static Future<bool> hasHardwareKey(String alias) async {
    if (!isAvailable) return false;
    return false;
  }

  /// Get random bytes from hardware RNG
  static Future<List<int>? > getHardwareRandom(int length) async {
    if (!isAvailable) return null;
    return null;
  }
}

/// Native security capabilities
class NativeCapabilities {
  final bool hasHardwareKeystore;
  final bool hasSecureEnclave;
  final bool hasStrongBox;
  final bool hasTEE;
  final bool hasHardwareRNG;
  final bool hasBiometricAuth;

  const NativeCapabilities({
    required this.hasHardwareKeystore,
    required this.hasSecureEnclave,
    required this. hasStrongBox,
    required this. hasTEE,
    required this. hasHardwareRNG,
    required this.hasBiometricAuth,
  });

  const NativeCapabilities.none()
      : hasHardwareKeystore = false,
        hasSecureEnclave = false,
        hasStrongBox = false,
        hasTEE = false,
        hasHardwareRNG = false,
        hasBiometricAuth = false;

  bool get hasAnyHardwareSecurity =>
      hasHardwareKeystore || hasSecureEnclave || hasStrongBox || hasTEE;

  @override
  String toString() => 'NativeCapabilities('
      'keystore: $hasHardwareKeystore, '
      'enclave: $hasSecureEnclave, '
      'strongbox: $hasStrongBox, '
      'tee: $hasTEE)';
}

/// Key types for hardware-backed keys
enum KeyType {
  ed25519,
  x25519,
  aes256,
}

/// Result of hardware key generation
class HardwareKeyResult {
  final bool success;
  final String? alias;
  final List<int>? publicKey;
  final String? error;

  const HardwareKeyResult._({
    required this.success,
    this.alias,
    this.publicKey,
    this.error,
  });

  factory HardwareKeyResult.success({
    required String alias,
    required List<int> publicKey,
  }) =>
      HardwareKeyResult. _(
        success:  true,
        alias: alias,
        publicKey: publicKey,
      );

  factory HardwareKeyResult.failure(String error) =>
      HardwareKeyResult._(success: false, error:  error);

  factory HardwareKeyResult.unsupported() =>
      HardwareKeyResult._(success: false, error: 'Hardware keys not supported');
}

/// Result of hardware signature operation
class SignatureResult {
  final bool success;
  final List<int>? signature;
  final String? error;

  const SignatureResult._({
    required this.success,
    this.signature,
    this.error,
  });

  factory SignatureResult. success(List<int> signature) =>
      SignatureResult. _(success: true, signature: signature);

  factory SignatureResult.failure(String error) =>
      SignatureResult._(success: false, error:  error);

  factory SignatureResult.unsupported() =>
      SignatureResult. _(success: false, error: 'Hardware signing not supported');
}

/// Result of hardware encryption operation
class EncryptionResult {
  final bool success;
  final List<int>? ciphertext;
  final String? error;

  const EncryptionResult._({
    required this. success,
    this.ciphertext,
    this.error,
  });

  factory EncryptionResult.success(List<int> ciphertext) =>
      EncryptionResult._(success: true, ciphertext: ciphertext);

  factory EncryptionResult.failure(String error) =>
      EncryptionResult._(success: false, error:  error);

  factory EncryptionResult.unsupported() =>
      EncryptionResult._(
          success: false, error: 'Hardware encryption not supported');
}