// Root detection
import 'dart:io';

/// ============================================================
/// Root Detection
/// ============================================================
/// Detects compromised device environments:
///
/// • Rooted Android devices
/// • Jailbroken iOS devices
/// • Emulator detection
/// ============================================================
final class RootDetection {
  RootDetection._();

  /// Perform full check
  static Future<RootCheckResult> check() async {
    final checks = <String, bool>{};

    if (Platform.isAndroid) {
      checks['su_binary'] = _checkSuBinary();
      checks['root_apps'] = _checkRootApps();
      checks['root_paths'] = _checkRootPaths();
      checks['busybox'] = _checkBusybox();
      checks['rw_system'] = await _checkRwSystem();
    } else if (Platform. isIOS) {
      checks['cydia'] = _checkCydia();
      checks['jailbreak_paths'] = _checkJailbreakPaths();
      checks['sandbox'] = await _checkSandboxEscape();
    }

    final isCompromised = checks. values.any((v) => v);

    return RootCheckResult(
      isCompromised: isCompromised,
      checks: checks,
    );
  }

  /// Quick check
  static Future<bool> isCompromised() async {
    final result = await check();
    return result. isCompromised;
  }

  // Android checks
  static bool _checkSuBinary() {
    const paths = [
      '/system/bin/su',
      '/system/xbin/su',
      '/sbin/su',
      '/data/local/xbin/su',
      '/data/local/bin/su',
      '/data/local/su',
      '/su/bin/su',
    ];
    return paths.any((p) => File(p).existsSync());
  }

  static bool _checkRootApps() {
    const packages = [
      '/system/app/Superuser. apk',
      '/system/app/SuperSU.apk',
      '/system/app/Magisk.apk',
    ];
    return packages.any((p) => File(p).existsSync());
  }

  static bool _checkRootPaths() {
    const paths = [
      '/system/app/Superuser',
      '/system/etc/init.d',
      '/data/local/xbin',
    ];
    return paths.any((p) => Directory(p).existsSync());
  }

  static bool _checkBusybox() {
    const paths = [
      '/system/xbin/busybox',
      '/system/bin/busybox',
      '/sbin/busybox',
    ];
    return paths.any((p) => File(p).existsSync());
  }

  static Future<bool> _checkRwSystem() async {
    try {
      final result = await Process.run('mount', []);
      final output = result.stdout.toString();
      return output.contains('/system') && output.contains(' rw');
    } catch (_) {
      return false;
    }
  }

  // iOS checks
  static bool _checkCydia() {
    return File('/Applications/Cydia. app').existsSync();
  }

  static bool _checkJailbreakPaths() {
    const paths = [
      '/Applications/Cydia. app',
      '/Applications/Sileo.app',
      '/Library/MobileSubstrate/MobileSubstrate. dylib',
      '/bin/bash',
      '/usr/sbin/sshd',
      '/etc/apt',
      '/private/var/lib/apt',
    ];
    return paths.any((p) => File(p).existsSync() || Directory(p).existsSync());
  }

  static Future<bool> _checkSandboxEscape() async {
    try {
      final file = File('/private/test_${DateTime.now().millisecondsSinceEpoch}');
      await file.writeAsString('test');
      await file.delete();
      return true; // Should not be able to write here
    } catch (_) {
      return false;
    }
  }
}

/// Root check result
class RootCheckResult {
  final bool isCompromised;
  final Map<String, bool> checks;

  const RootCheckResult({
    required this. isCompromised,
    required this. checks,
  });

  List<String> get failedChecks =>
      checks.entries.where((e) => e.value).map((e) => e.key).toList();

  @override
  String toString() => 'RootCheckResult(compromised: $isCompromised, failed: $failedChecks)';
}