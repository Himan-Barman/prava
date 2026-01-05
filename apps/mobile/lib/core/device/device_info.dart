import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

class DeviceDescriptor {
  DeviceDescriptor({
    required this.platform,
    required this.name,
  });

  final String platform;
  final String name;
}

class DeviceInfoSnapshot {
  static final DeviceInfoPlugin _plugin = DeviceInfoPlugin();
  static DeviceDescriptor? _cached;

  static Future<DeviceDescriptor?> load() async {
    if (_cached != null) return _cached;

    try {
      if (Platform.isAndroid) {
        final info = await _plugin.androidInfo;
        final brand = info.brand.trim();
        final model = info.model.trim();
        final name = _joinParts([brand, model], fallback: 'Android device');
        _cached = DeviceDescriptor(platform: 'android', name: name);
        return _cached;
      }

      if (Platform.isIOS) {
        final info = await _plugin.iosInfo;
        final name = _joinParts(
          [info.name.trim(), info.model.trim()],
          fallback: 'iOS device',
        );
        _cached = DeviceDescriptor(platform: 'ios', name: name);
        return _cached;
      }

      if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        _cached = DeviceDescriptor(platform: 'desktop', name: 'Desktop');
        return _cached;
      }
    } catch (_) {}

    return null;
  }

  static String _joinParts(
    List<String> parts, {
    required String fallback,
  }) {
    final filtered = parts.where((part) => part.isNotEmpty).toList();
    if (filtered.isEmpty) return fallback;
    return filtered.join(' ');
  }
}
