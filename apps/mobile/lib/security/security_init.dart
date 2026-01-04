// Security initialization helper
import 'dart:async';
import 'dart:io';

import 'bridge/sodium_loader.dart';
import 'bridge/memory_allocator.dart';
import 'bridge/native_api.dart';
import 'storage/vault.dart';
import 'threat/root_detection.dart';
import 'threat/debugger_check.dart';

/// ============================================================
/// Security Module Initialization
/// ============================================================
/// Call once at app startup before any security operations. 
///
/// Usage:
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   
///   final result = await SecurityInit.initialize();
///   if (! result. success) {
///     // Handle security initialization failure
///     exit(1);
///   }
///   
///   runApp(MyApp());
/// }
/// ```
/// ============================================================
final class SecurityInit {
  SecurityInit._();

  static bool _initialized = false;
  static SecurityInitResult?  _result;
  static final _initLock = Completer<void>();

  /// Check if security module is initialized
  static bool get isInitialized => _initialized;

  /// Get last initialization result
  static SecurityInitResult? get lastResult => _result;

  /// Initialize security module with full configuration
  static Future<SecurityInitResult> initialize({
    SecurityConfig config = const SecurityConfig(),
  }) async {
    if (_initialized && _result != null) {
      return _result!;
    }

    final stopwatch = Stopwatch()..start();
    final warnings = <String>[];
    final errors = <String>[];

    try {
      // ─────────────────────────────────────────────────────
      // Phase 1: Core Initialization
      // ─────────────────────────────────────────────────────
      
      // 1.1 Initialize memory allocator
      MemoryAllocator.initialize();

      // 1.2 Initialize native security library
      final hasNative = await NativeApi.initialize();
      if (!hasNative) {
        warnings.add('Native security library unavailable - using fallback');
      }

      // 1.3 Initialize libsodium
      try {
        await SodiumLoader. warmUp();
      } catch (e) {
        errors.add('Failed to initialize libsodium:  $e');
        return SecurityInitResult. failure(
          error: 'Cryptographic library initialization failed',
          errors: errors,
          initTimeMs: stopwatch. elapsedMilliseconds,
        );
      }

      // ─────────────────────────────────────────────────────
      // Phase 2: Security Environment Checks
      // ─────────────────────────────────────────────────────

      // 2.1 Root/Jailbreak detection
      if (config.checkRootedDevice) {
        final rootResult = await RootDetection.check();
        if (rootResult.isCompromised) {
          if (config.blockRootedDevices) {
            return SecurityInitResult.failure(
              error:  'Device security compromised:  ${rootResult.failedChecks. join(", ")}',
              errors: ['Root/jailbreak detected'],
              initTimeMs: stopwatch.elapsedMilliseconds,
            );
          }
          warnings.add('Device may be rooted/jailbroken:  ${rootResult.failedChecks.join(", ")}');
        }
      }

      // 2.2 Debugger detection
      if (config.checkDebugger) {
        final debugResult = await DebuggerCheck.check();
        if (debugResult.isBeingDebugged) {
          if (config.blockDebugger) {
            return SecurityInitResult.failure(
              error:  'Debugging detected: ${debugResult. detectedMethods.join(", ")}',
              errors: ['Debugger attached'],
              initTimeMs: stopwatch. elapsedMilliseconds,
            );
          }
          warnings.add('Debugger detected: ${debugResult.detectedMethods.join(", ")}');
        }
      }

      // ─────────────────────────────────────────────────────
      // Phase 3: Storage Initialization
      // ─────────────────────────────────────────────────────

      // 3.1 Initialize secure vault
      try {
        await Vault.initialize(
          encryptionKey: config.vaultEncryptionKey,
        );
      } catch (e) {
        errors.add('Failed to initialize secure storage: $e');
        return SecurityInitResult.failure(
          error: 'Secure storage initialization failed',
          errors: errors,
          initTimeMs: stopwatch. elapsedMilliseconds,
        );
      }

      // ─────────────────────────────────────────────────────
      // Phase 4:  Finalization
      // ─────────────────────────────────────────────────────

      stopwatch.stop();

      _initialized = true;
      _result = SecurityInitResult. success(
        initTimeMs: stopwatch.elapsedMilliseconds,
        warnings: warnings,
        capabilities: SecurityCapabilities(
          hasHardwareKeystore: NativeApi.getCapabilities().hasHardwareKeystore,
          hasSecureEnclave: NativeApi.getCapabilities().hasSecureEnclave,
          hasStrongBox: NativeApi.getCapabilities().hasStrongBox,
          hasBiometrics: await _checkBiometrics(),
          platformSecurity: _getPlatformSecurityLevel(),
        ),
      );

      return _result! ;

    } catch (e, st) {
      stopwatch.stop();
      errors.add('Unexpected error:  $e');
      return SecurityInitResult.failure(
        error: 'Security initialization failed unexpectedly',
        errors: errors,
        stackTrace: st,
        initTimeMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  /// Shutdown security module (call on app termination)
  static Future<void> shutdown() async {
    if (!_initialized) return;

    // Clear all sensitive data from memory
    MemoryAllocator. cleanupAll();

    // Close secure storage
    await Vault.close();

    _initialized = false;
    _result = null;
  }

  /// Re-initialize after shutdown
  static Future<SecurityInitResult> reinitialize({
    SecurityConfig config = const SecurityConfig(),
  }) async {
    await shutdown();
    return initialize(config: config);
  }

  static Future<bool> _checkBiometrics() async {
    // Platform-specific biometric check
    return Platform.isAndroid || Platform.isIOS;
  }

  static PlatformSecurityLevel _getPlatformSecurityLevel() {
    if (Platform. isIOS) {
      return PlatformSecurityLevel.high; // Secure Enclave
    } else if (Platform. isAndroid) {
      return PlatformSecurityLevel. medium; // Varies by device
    }
    return PlatformSecurityLevel. low;
  }
}

/// Security initialization configuration
class SecurityConfig {
  final bool checkRootedDevice;
  final bool blockRootedDevices;
  final bool checkDebugger;
  final bool blockDebugger;
  final String?  vaultEncryptionKey;
  final bool enableKeyTransparency;
  final Duration sessionTimeout;

  const SecurityConfig({
    this.checkRootedDevice = true,
    this.blockRootedDevices = false,
    this.checkDebugger = true,
    this. blockDebugger = false,
    this.vaultEncryptionKey,
    this.enableKeyTransparency = true,
    this.sessionTimeout = const Duration(days: 30),
  });

  /// Production configuration (strict)
  factory SecurityConfig.production() => const SecurityConfig(
        checkRootedDevice: true,
        blockRootedDevices:  true,
        checkDebugger: true,
        blockDebugger: true,
        enableKeyTransparency:  true,
      );

  /// Development configuration (relaxed)
  factory SecurityConfig.development() => const SecurityConfig(
        checkRootedDevice: false,
        blockRootedDevices:  false,
        checkDebugger: false,
        blockDebugger: false,
        enableKeyTransparency: false,
      );
}

/// Security initialization result
class SecurityInitResult {
  final bool success;
  final String? error;
  final List<String> errors;
  final List<String> warnings;
  final StackTrace? stackTrace;
  final int initTimeMs;
  final SecurityCapabilities?  capabilities;

  const SecurityInitResult._({
    required this.success,
    this.error,
    this.errors = const [],
    this.warnings = const [],
    this. stackTrace,
    required this.initTimeMs,
    this. capabilities,
  });

  factory SecurityInitResult.success({
    required int initTimeMs,
    List<String> warnings = const [],
    required SecurityCapabilities capabilities,
  }) =>
      SecurityInitResult. _(
        success:  true,
        initTimeMs: initTimeMs,
        warnings: warnings,
        capabilities: capabilities,
      );

  factory SecurityInitResult.failure({
    required String error,
    List<String> errors = const [],
    StackTrace? stackTrace,
    required int initTimeMs,
  }) =>
      SecurityInitResult._(
        success: false,
        error:  error,
        errors: errors,
        stackTrace: stackTrace,
        initTimeMs: initTimeMs,
      );

  @override
  String toString() {
    if (success) {
      return 'SecurityInitResult:  SUCCESS in ${initTimeMs}ms'
          '${warnings.isNotEmpty ? ", warnings: $warnings" : ""}';
    }
    return 'SecurityInitResult: FAILED - $error';
  }
}

/// Device security capabilities
class SecurityCapabilities {
  final bool hasHardwareKeystore;
  final bool hasSecureEnclave;
  final bool hasStrongBox;
  final bool hasBiometrics;
  final PlatformSecurityLevel platformSecurity;

  const SecurityCapabilities({
    required this.hasHardwareKeystore,
    required this.hasSecureEnclave,
    required this.hasStrongBox,
    required this.hasBiometrics,
    required this. platformSecurity,
  });

  bool get hasHardwareSecurity =>
      hasHardwareKeystore || hasSecureEnclave || hasStrongBox;

  @override
  String toString() => 'SecurityCapabilities('
      'hardware: $hasHardwareSecurity, '
      'biometrics: $hasBiometrics, '
      'level: $platformSecurity)';
}

/// Platform security level
enum PlatformSecurityLevel {
  low,
  medium,
  high,
}