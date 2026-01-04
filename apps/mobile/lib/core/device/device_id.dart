import 'dart:math';

import '../storage/secure_store.dart';

class DeviceIdStore {
  DeviceIdStore(this._store);

  final SecureStore _store;

  Future<String> getOrCreate() async {
    final existing = await _store.getDeviceId();
    if (existing != null && existing.length >= 10) {
      return existing;
    }

    final id = _generateId();
    await _store.setDeviceId(id);
    return id;
  }

  String _generateId() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    final buffer = StringBuffer();
    for (final b in bytes) {
      buffer.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}
