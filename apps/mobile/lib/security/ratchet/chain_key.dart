// Chain key derivation
import 'dart:typed_data';

import 'package:sodium_libs/sodium_libs.dart';

import '../bridge/sodium_loader.dart';
import '../crypto/hashing.dart';

/// ============================================================
/// Chain Key Management
/// ============================================================
/// Manages symmetric-key ratchet chains for Double Ratchet: 
///
/// Chain Key (CK):
/// • 32-byte symmetric key
/// • Advanced after each message
/// • Derives message keys
///
/// Derivation: 
/// • Message Key = HMAC(CK, 0x01)
/// • Next Chain Key = HMAC(CK, 0x02)
///
/// Security Properties:
/// • Forward secrecy within chain
/// • Cannot derive previous keys from current
/// ============================================================
final class ChainKey {
  final Uint8List _key;
  final int index;

  ChainKey. _(this._key, this.index);

  /// Create chain key from bytes
  factory ChainKey.fromBytes(Uint8List key, {int index = 0}) {
    if (key.length != 32) {
      throw ArgumentError('Chain key must be 32 bytes');
    }
    return ChainKey._(Uint8List.fromList(key), index);
  }

  /// Create chain key from SecureKey
  static Future<ChainKey> fromSecureKey(SecureKey key, {int index = 0}) async {
    final bytes = key.extractBytes();
    return ChainKey.fromBytes(bytes, index: index);
  }

  /// Get raw key bytes (use carefully)
  Uint8List get key => Uint8List.fromList(_key);

  /// Advance chain and derive message key
  Future<ChainKeyAdvance> advance() async {
    final derived = await Hashing.kdfChainKey(_key);

    return ChainKeyAdvance(
      messageKey: derived. messageKey,
      nextChainKey:  ChainKey._(derived.nextChainKey, index + 1),
    );
  }

  /// Advance chain synchronously
  ChainKeyAdvance advanceSync() {
    final sodium = SodiumLoader.sodiumSync;

    // Message key = HMAC(CK, 0x01)
    final messageKey = sodium.crypto.genericHash(
      message:  Uint8List.fromList([0x01, ..._key]),
      outLen: 32,
    );

    // Next chain key = HMAC(CK, 0x02)
    final nextChainKey = sodium.crypto.genericHash(
      message:  Uint8List. fromList([0x02, ..._key]),
      outLen: 32,
    );

    return ChainKeyAdvance(
      messageKey: messageKey,
      nextChainKey: ChainKey._(nextChainKey, index + 1),
    );
  }

  /// Convert to SecureKey
  Future<SecureKey> toSecureKey() async {
    final sodium = await SodiumLoader. sodium;
    return sodium.secureCopy(_key);
  }

  /// Zero the key material
  void dispose() {
    for (var i = 0; i < _key. length; i++) {
      _key[i] = 0;
    }
  }

  /// Serialize for storage
  Map<String, dynamic> toJson() => {
        'key': _key.toList(),
        'index': index,
      };

  /// Deserialize from storage
  factory ChainKey.fromJson(Map<String, dynamic> json) {
    return ChainKey._(
      Uint8List.fromList((json['key'] as List).cast<int>()),
      json['index'] as int,
    );
  }
}

/// Result of advancing a chain key
class ChainKeyAdvance {
  /// Message key derived from current chain key
  final Uint8List messageKey;

  /// Next chain key after advancement
  final ChainKey nextChainKey;

  const ChainKeyAdvance({
    required this. messageKey,
    required this.nextChainKey,
  });

  /// Zero the message key
  void disposeMessageKey() {
    for (var i = 0; i < messageKey.length; i++) {
      messageKey[i] = 0;
    }
  }
}