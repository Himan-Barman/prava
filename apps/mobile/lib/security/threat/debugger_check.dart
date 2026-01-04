// Debugger detection
import 'dart:io';

/// ============================================================
/// Debugger Check
/// ============================================================
/// Detects debugging and instrumentation:
///
/// • ptrace detection
/// • Frida detection
/// • Xposed detection
/// ============================================================
final class DebuggerCheck {
  DebuggerCheck._();

  /// Perform full check
  static Future<DebugCheckResult> check() async {
    final checks = <String, bool>{};

    if (Platform.isAndroid) {
      checks['tracer'] = await _checkTracerPid();
      checks['frida'] = _checkFrida();
      checks['xposed'] = _checkXposed();
    }

    checks['debug_mode'] = _isDebugMode();

    final isBeingDebugged = checks. values.any((v) => v);

    return DebugCheckResult(
      isBeingDebugged: isBeingDebugged,
      checks: checks,
    );
  }

  /// Quick check
  static Future<bool> isBeingDebugged() async {
    final result = await check();
    return result. isBeingDebugged;
  }

  static Future<bool> _checkTracerPid() async {
    try {
      final status = await File('/proc/self/status').readAsString();
      final match = RegExp(r'TracerPid:\s*(\d+)').firstMatch(status);
      if (match != null) {
        final pid = int.tryParse(match. group(1) ?? '0') ?? 0;
        return pid != 0;
      }
    } catch (_) {}
    return false;
  }

  static bool _checkFrida() {
    const paths = [
      '/data/local/tmp/frida-server',
      '/data/local/tmp/re. frida.server',
    ];

    if (paths.any((p) => File(p).existsSync())) {
      return true;
    }

    try {
      final maps = File('/proc/self/maps').readAsStringSync();
      if (maps.contains('frida') || maps.contains('gadget')) {
        return true;
      }
    } catch (_) {}

    return false;
  }

  static bool _checkXposed() {
    const paths = [
      '/system/framework/XposedBridge.jar',
      '/system/lib/libxposed_art.so',
      '/system/lib64/libxposed_art.so',
    ];
    return paths.any((p) => File(p).existsSync());
  }

  static bool _isDebugMode() {
    bool debugMode = false;
    assert(() {
      debugMode = true;
      return true;
    }());
    return debugMode;
  }
}

/// Debug check result
class DebugCheckResult {
  final bool isBeingDebugged;
  final Map<String, bool> checks;

  const DebugCheckResult({
    required this.isBeingDebugged,
    required this.checks,
  });

  List<String> get detectedMethods =>
      checks.entries.where((e) => e.value).map((e) => e.key).toList();

  @override
  String toString() => 'DebugCheckResult(debugging: $isBeingDebugged, methods: $detectedMethods)';
}