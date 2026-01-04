// Screenshot prevention
import 'package:flutter/services.dart';

/// ============================================================
/// Screen Protector
/// ============================================================
/// Prevents screen capture: 
///
/// • Screenshot blocking
/// • Screen recording blocking
/// • App switcher protection
/// ============================================================
final class ScreenProtector {
  ScreenProtector._();

  static const _channel = MethodChannel('prava_security');
  static bool _enabled = false;

  /// Check if protection is enabled
  static bool get isEnabled => _enabled;

  /// Enable screen protection
  static Future<bool> enable() async {
    if (_enabled) return true;

    try {
      final result = await _channel.invokeMethod<bool>('enableSecure');
      _enabled = result ??  false;
      return _enabled;
    } on PlatformException catch (_) {
      return false;
    } on MissingPluginException catch (_) {
      return false;
    }
  }

  /// Disable screen protection
  static Future<bool> disable() async {
    if (!_enabled) return true;

    try {
      final result = await _channel.invokeMethod<bool>('disableSecure');
      _enabled = !(result ?? true);
      return !_enabled;
    } on PlatformException catch (_) {
      return false;
    } on MissingPluginException catch (_) {
      return false;
    }
  }

  /// Protect during callback execution
  static Future<T> protectDuring<T>(Future<T> Function() callback) async {
    final wasEnabled = _enabled;

    if (!wasEnabled) {
      await enable();
    }

    try {
      return await callback();
    } finally {
      if (!wasEnabled) {
        await disable();
      }
    }
  }
}