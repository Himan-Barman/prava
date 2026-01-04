import 'dart:convert';
import 'dart:typed_data';

/// Manages skipped message keys for out-of-order message delivery
class SkippedMessageKeys {
  /// Maximum number of keys to skip per chain
  static const int maxSkipPerChain = 1000;

  /// Maximum total skipped keys to store
  static const int maxTotalKeys = 5000;

  /// Key expiration time in milliseconds (7 days)
  static const int expirationMs = 7 * 24 * 60 * 60 * 1000;

  /// Maximum persisted keys to store for history replay
  static const int maxPersistedKeys = 50000;

  /// Persisted key expiration time in milliseconds (0 disables expiration)
  static const int persistedExpirationMs = 0;

  /// Stored skipped keys:  Map<ratchetPublicKeyHex, Map<messageNumber, StoredKey>>
  final Map<String, Map<int, _StoredKey>> _keys;

  /// Persisted message keys for history replay
  final Map<String, Map<int, _StoredKey>> _persisted;

  /// Private constructor
  SkippedMessageKeys._(this._keys, this._persisted);

  /// Create empty instance
  factory SkippedMessageKeys.empty() {
    return SkippedMessageKeys._({}, {});
  }

  /// Create from JSON
  factory SkippedMessageKeys.fromJson(Map<String, dynamic> json) {
    final skippedRaw = json['skipped'];
    final persistedRaw = json['persisted'];
    if (skippedRaw is Map<String, dynamic> ||
        persistedRaw is Map<String, dynamic>) {
      return SkippedMessageKeys._(
        _parseChains(skippedRaw),
        _parseChains(persistedRaw),
      );
    }

    return SkippedMessageKeys._(_parseChains(json), {});
  }

  /// Number of stored keys
  int get count {
    var total = 0;
    for (final chain in _keys.values) {
      total += chain.length;
    }
    return total;
  }

  int get persistedCount {
    var total = 0;
    for (final chain in _persisted.values) {
      total += chain.length;
    }
    return total;
  }

  /// Store a skipped message key
  void storeKey(
    Uint8List ratchetPublicKey,
    int messageNumber,
    Uint8List messageKey,
  ) {
    if (count >= maxTotalKeys) {
      _removeOldest();
    }

    final keyHex = _bytesToHex(ratchetPublicKey);
    _keys. putIfAbsent(keyHex, () => {});
    _keys[keyHex]![messageNumber] = _StoredKey(
      key: Uint8List.fromList(messageKey),
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Store a persisted message key for history replay
  void storePersistentKey(
    Uint8List ratchetPublicKey,
    int messageNumber,
    Uint8List messageKey,
  ) {
    if (persistedCount >= maxPersistedKeys) {
      _removeOldestPersisted();
    }

    final keyHex = _bytesToHex(ratchetPublicKey);
    _persisted.putIfAbsent(keyHex, () => {});
    _persisted[keyHex]![messageNumber] = _StoredKey(
      key: Uint8List.fromList(messageKey),
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Consume (get and remove) a skipped message key
  Uint8List?  consumeKey(Uint8List ratchetPublicKey, int messageNumber) {
    final keyHex = _bytesToHex(ratchetPublicKey);
    final chain = _keys[keyHex];
    if (chain == null) return null;

    final stored = chain. remove(messageNumber);
    if (stored == null) return null;

    if (chain.isEmpty) {
      _keys.remove(keyHex);
    }

    return stored.key;
  }

  /// Get a persisted message key without removing it
  Uint8List? getPersistentKey(
    Uint8List ratchetPublicKey,
    int messageNumber,
  ) {
    final keyHex = _bytesToHex(ratchetPublicKey);
    final chain = _persisted[keyHex];
    if (chain == null) return null;

    final stored = chain[messageNumber];
    if (stored == null) return null;

    return Uint8List.fromList(stored.key);
  }

  /// Remove a persisted message key
  void removePersistentKey(
    Uint8List ratchetPublicKey,
    int messageNumber,
  ) {
    final keyHex = _bytesToHex(ratchetPublicKey);
    final chain = _persisted[keyHex];
    if (chain == null) return;
    final stored = chain.remove(messageNumber);
    if (stored != null) {
      _zeroize(stored.key);
    }
    if (chain.isEmpty) {
      _persisted.remove(keyHex);
    }
  }

  /// Remove expired keys
  void removeExpired() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final cutoff = now - expirationMs;

    for (final chain in _keys.values) {
      chain.removeWhere((_, stored) => stored.timestamp < cutoff);
    }

    _keys.removeWhere((_, chain) => chain.isEmpty);
    _removeExpiredPersisted();
  }

  /// Clear all keys
  void clear() {
    for (final chain in _keys.values) {
      for (final stored in chain.values) {
        _zeroize(stored. key);
      }
    }
    _keys.clear();
    for (final chain in _persisted.values) {
      for (final stored in chain.values) {
        _zeroize(stored.key);
      }
    }
    _persisted.clear();
  }

  /// Serialize to JSON
  Map<String, dynamic> toJson() {
    return {
      'skipped': _serializeChains(_keys, encodeBase64: false),
      'persisted': _serializeChains(_persisted, encodeBase64: true),
    };
  }

  void _removeOldest() {
    int?  oldestTime;
    String? oldestChain;
    int? oldestNumber;

    for (final entry in _keys.entries) {
      for (final keyEntry in entry.value.entries) {
        if (oldestTime == null || keyEntry.value. timestamp < oldestTime) {
          oldestTime = keyEntry. value.timestamp;
          oldestChain = entry.key;
          oldestNumber = keyEntry.key;
        }
      }
    }

    if (oldestChain != null && oldestNumber != null) {
      final stored = _keys[oldestChain]?. remove(oldestNumber);
      if (stored != null) {
        _zeroize(stored.key);
      }
      if (_keys[oldestChain]?.isEmpty ??  false) {
        _keys.remove(oldestChain);
      }
    }
  }

  void _removeOldestPersisted() {
    int? oldestTime;
    String? oldestChain;
    int? oldestNumber;

    for (final entry in _persisted.entries) {
      for (final keyEntry in entry.value.entries) {
        if (oldestTime == null || keyEntry.value.timestamp < oldestTime) {
          oldestTime = keyEntry.value.timestamp;
          oldestChain = entry.key;
          oldestNumber = keyEntry.key;
        }
      }
    }

    if (oldestChain != null && oldestNumber != null) {
      final stored = _persisted[oldestChain]?.remove(oldestNumber);
      if (stored != null) {
        _zeroize(stored.key);
      }
      if (_persisted[oldestChain]?.isEmpty ?? false) {
        _persisted.remove(oldestChain);
      }
    }
  }

  void _removeExpiredPersisted() {
    if (persistedExpirationMs <= 0) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final cutoff = now - persistedExpirationMs;

    for (final chain in _persisted.values) {
      chain.removeWhere((_, stored) => stored.timestamp < cutoff);
    }

    _persisted.removeWhere((_, chain) => chain.isEmpty);
  }

  static Map<String, Map<int, _StoredKey>> _parseChains(dynamic raw) {
    if (raw is! Map<String, dynamic>) return {};
    final keys = <String, Map<int, _StoredKey>>{};

    for (final entry in raw.entries) {
      final chainKeys = <int, _StoredKey>{};
      final chainData = entry.value;
      if (chainData is! Map<String, dynamic>) continue;

      for (final keyEntry in chainData.entries) {
        final messageNum = int.tryParse(keyEntry.key);
        if (messageNum == null) continue;
        final stored = keyEntry.value;
        if (stored is! Map<String, dynamic>) continue;
        final keyBytes = _decodeKey(stored['key']);
        final timestamp = stored['timestamp'] as int? ?? 0;
        if (keyBytes == null || keyBytes.isEmpty) continue;
        chainKeys[messageNum] = _StoredKey(
          key: keyBytes,
          timestamp: timestamp,
        );
      }

      if (chainKeys.isNotEmpty) {
        keys[entry.key] = chainKeys;
      }
    }

    return keys;
  }

  static Map<String, dynamic> _serializeChains(
    Map<String, Map<int, _StoredKey>> chains, {
    required bool encodeBase64,
  }) {
    final result = <String, dynamic>{};

    for (final entry in chains.entries) {
      final chainData = <String, dynamic>{};
      for (final keyEntry in entry.value.entries) {
        chainData[keyEntry.key.toString()] = {
          'key': encodeBase64
              ? base64Encode(keyEntry.value.key)
              : keyEntry.value.key.toList(),
          'timestamp': keyEntry.value.timestamp,
        };
      }
      result[entry.key] = chainData;
    }

    return result;
  }

  static Uint8List? _decodeKey(dynamic value) {
    if (value is List) {
      return Uint8List.fromList(value.cast<int>());
    }
    if (value is String && value.isNotEmpty) {
      try {
        return Uint8List.fromList(base64Decode(value));
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static void _zeroize(Uint8List buffer) {
    for (var i = 0; i < buffer.length; i++) {
      buffer[i] = 0;
    }
  }
}

class _StoredKey {
  final Uint8List key;
  final int timestamp;

  _StoredKey({required this.key, required this.timestamp});
}
