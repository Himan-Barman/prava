import 'dart:convert';

import 'package:flutter/services.dart';

import '../core/storage/secure_store.dart';

class PlatformBridgeService {
  PlatformBridgeService({SecureStore? store}) : _store = store ?? SecureStore();

  static const MethodChannel _channel = MethodChannel('prava/platform');

  final SecureStore _store;

  Future<bool> shareText(String text) async {
    final value = text.trim();
    if (value.isEmpty) return false;

    try {
      final shared = await _channel.invokeMethod<bool>(
        'shareText',
        {'text': value},
      );
      return shared == true;
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: value));
      return false;
    }
  }

  Future<void> requestLocationTimeAccess() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'requestLocationTimeAccess',
      );
      if (result == null) return;
      final payload = <String, dynamic>{
        'timeZoneName': result['timeZoneName']?.toString() ?? '',
        'timeZoneOffsetMinutes':
            int.tryParse(result['timeZoneOffsetMinutes']?.toString() ?? '') ??
                DateTime.now().timeZoneOffset.inMinutes,
        'permissionGranted': result['permissionGranted'] == true,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      };
      await _store.setLocalTimeZoneJson(jsonEncode(payload));
    } catch (_) {
      final payload = <String, dynamic>{
        'timeZoneName': DateTime.now().timeZoneName,
        'timeZoneOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
        'permissionGranted': false,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      };
      await _store.setLocalTimeZoneJson(jsonEncode(payload));
    }
  }
}
